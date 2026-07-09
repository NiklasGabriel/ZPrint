//
//  PrintWorkspaceView.swift
//  ZPrint
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PrintWorkspaceView: View {
    @Binding var document: ZPrintDocument
    @StateObject private var printerManager = PrinterManager()
    @State private var copiedFeedbackDate: Date?
    @State private var preparedJob: RawPrintJob?
    @State private var printStatus: PrintWorkspaceStatus?
    @State private var isPreparingJob = false
    @State private var isSendingPrintJob = false
    @State private var showsPrintConfirmation = false

    private var zpl: String {
        ZPLEngine.generateBatchZPL(document: document)
    }

    private var zplIsEmpty: Bool {
        zpl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var zplDiagnostics: [ZPLDiagnostic] {
        ZPLEngine.diagnostics(for: document)
    }

    private var printerValidation: PrinterSelectionValidation {
        printerManager.validation(for: document.printSettings.selectedPrinterName)
    }

    private var hasErrors: Bool {
        zplDiagnostics.contains { $0.level == .error } || printerValidation != .valid || zplIsEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            controlsBar

            Divider()

            zplOutput
        }
        .background(ZPrintDesign.ColorToken.workspaceBackground)
        .task {
            await refreshPrinters()
        }
        .onChange(of: document.printSettings.selectedPrinterName) { _, newValue in
            printerManager.lastSelectedPrinterName = newValue
            preparedJob = nil
        }
        .onChange(of: zpl) { _, _ in
            preparedJob = nil
        }
        .alert("Raw-ZPL drucken?", isPresented: $showsPrintConfirmation) {
            Button("Drucken", role: .destructive) {
                Task {
                    await sendPreparedJob()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der ZPL-Code wird direkt an „\(document.printSettings.selectedPrinterName ?? "Drucker")“ gesendet. Bitte nur mit einem Zebra-/ZPL-kompatiblen Drucker verwenden.")
        }
    }

    private var controlsBar: some View {
        HStack(alignment: .top, spacing: 12) {
            printerPanel
            printSettingsPanel

            if !sequenceVariables.isEmpty {
                sequenceSettingsPanel
            }

            diagnosticsPanel

            Spacer(minLength: 10)

            actionsPanel
        }
        .padding(14)
        .background(ZPrintDesign.ColorToken.ribbonBackground.opacity(0.86))
    }

    private var printerPanel: some View {
        PrintControlPanel(title: "Drucker") {
            HStack(spacing: 8) {
                Picker("Drucker", selection: selectedPrinterBinding) {
                    Text("Drucker wählen").tag("")

                    ForEach(printerManager.printers) { printer in
                        Text(printer.displayName).tag(printer.name)
                    }
                }
                .labelsHidden()
                .frame(width: 210)
                .disabled(printerManager.state == .loading || printerManager.printers.isEmpty)

                Button {
                    Task {
                        await refreshPrinters()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.bordered)
                .disabled(printerManager.state == .loading)
                .help("Drucker neu laden")
            }

            printerStateText

            if let selectedPrinter = printerManager.printer(named: document.printSettings.selectedPrinterName),
               let deviceURI = selectedPrinter.deviceURI {
                Text(deviceURI)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 244, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var printerStateText: some View {
        switch printerManager.state {
        case .idle:
            Text("Noch nicht geladen.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        case .loading:
            Label("Drucker werden geladen", systemImage: "hourglass")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        case .ready:
            if let message = printerValidation.message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
            } else {
                Label("\(printerManager.printers.count) Drucker verfügbar", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.green)
            }
        case .empty:
            Label("Kein lokaler Drucker gefunden", systemImage: "printer.slash")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.orange)
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.red)
        }
    }

    private var printSettingsPanel: some View {
        PrintControlPanel(title: "Druckbereich") {
            HStack(alignment: .top, spacing: 8) {
                PrintNumberControl(title: "Start", value: $document.printSettings.counterStart)
                PrintNumberControl(title: "Ende", value: $document.printSettings.counterEnd)
                PrintNumberControl(title: "Anzahl", value: $document.printSettings.copiesPerNumber)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Format")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("00000", text: $document.printSettings.numberFormat)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .frame(width: 76, height: 28)
                        .background {
                            Capsule()
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.78))
                        }
                        .overlay {
                            Capsule()
                                .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
                        }
                }
            }

            Text(sequenceVariables.isEmpty ? "Fallback für {{number}}." : "Sequenzvariablen nutzen eigene Bereiche.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private var sequenceSettingsPanel: some View {
        PrintControlPanel(title: "Sequenzvariablen") {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(sequenceVariables) { variable in
                        SequencePrintControlCard(
                            variable: variable,
                            startValue: printRangeValueBinding(for: variable, keyPath: \.startValue),
                            endValue: printRangeValueBinding(for: variable, keyPath: \.endValue),
                            copiesPerValue: printRangeValueBinding(for: variable, keyPath: \.copiesPerValue)
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: 460)
        }
    }

    private var diagnosticsPanel: some View {
        PrintControlPanel(title: "Status") {
            VStack(alignment: .leading, spacing: 5) {
                if zplDiagnostics.isEmpty && printerValidation == .valid && !zplIsEmpty {
                    Label("Druckauftrag bereit", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                } else {
                    if zplIsEmpty {
                        statusLabel("ZPL ist leer.", systemImage: "xmark.octagon.fill", color: .red)
                    }

                    if let message = printerValidation.message {
                        statusLabel(message, systemImage: "printer.slash", color: .orange)
                    }

                    ForEach(zplDiagnostics) { diagnostic in
                        statusLabel(
                            diagnostic.message,
                            systemImage: diagnostic.level == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill",
                            color: diagnostic.level == .error ? .red : .orange
                        )
                    }
                }

                if let printStatus {
                    Divider()
                    printStatusView(printStatus)
                }

                Text("\(labelCount) Etikett\(labelCount == 1 ? "" : "en")")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: 280)
    }

    private var actionsPanel: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button {
                copyZPL()
            } label: {
                Label(copiedFeedbackDate == nil ? "ZPL kopieren" : "Kopiert", systemImage: copiedFeedbackDate == nil ? "doc.on.doc" : "checkmark")
                    .frame(width: 168)
            }
            .buttonStyle(.borderedProminent)
            .disabled(zplIsEmpty || zplDiagnostics.contains { $0.level == .error })

            Button {
                exportZPL()
            } label: {
                Label("ZPL exportieren", systemImage: "square.and.arrow.down")
                    .frame(width: 168)
            }
            .buttonStyle(.bordered)
            .disabled(zplIsEmpty || zplDiagnostics.contains { $0.level == .error })

            Button {
                Task {
                    await prepareJob()
                }
            } label: {
                Label("Auftrag vorbereiten", systemImage: "doc.badge.gearshape")
                    .frame(width: 168)
            }
            .buttonStyle(.bordered)
            .disabled(hasErrors || isPreparingJob)

            Button {
                showsPrintConfirmation = true
            } label: {
                Label(isSendingPrintJob ? "Senden..." : "Drucken", systemImage: "printer")
                    .frame(width: 168)
            }
            .buttonStyle(.bordered)
            .disabled(hasErrors || preparedJob == nil || isSendingPrintJob)
        }
    }

    private var zplOutput: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(zpl)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollContentBackground(.hidden)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
        }
        .padding(18)
    }

    private var selectedPrinterBinding: Binding<String> {
        Binding(
            get: { document.printSettings.selectedPrinterName ?? "" },
            set: { newValue in
                document.printSettings.selectedPrinterName = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private var sequenceVariables: [VariableDefinition] {
        document.variables.filter { $0.type == .sequence }
    }

    private var labelCount: Int {
        max(1, VariableEngine.batchContexts(for: document).count)
    }

    private func refreshPrinters() async {
        await printerManager.refreshPrinters()

        if let selectedPrinterName = document.printSettings.selectedPrinterName,
           printerManager.printer(named: selectedPrinterName) != nil {
            return
        }

        if let lastSelectedPrinterName = printerManager.lastSelectedPrinterName,
           printerManager.printer(named: lastSelectedPrinterName) != nil {
            document.printSettings.selectedPrinterName = lastSelectedPrinterName
        }
    }

    private func copyZPL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(zpl, forType: .string)
        copiedFeedbackDate = Date()
        printStatus = .info("ZPL wurde in die Zwischenablage kopiert.")
    }

    private func exportZPL() {
        let savePanel = NSSavePanel()
        savePanel.title = "ZPL exportieren"
        savePanel.nameFieldStringValue = "\(document.documentName.replacingOccurrences(of: " ", with: "-")).zpl"

        if let zplType = UTType(filenameExtension: "zpl") {
            savePanel.allowedContentTypes = [zplType]
        } else {
            savePanel.allowedContentTypes = [.plainText]
        }

        guard savePanel.runModal() == .OK,
              let url = savePanel.url else {
            return
        }

        do {
            try zpl.write(to: url, atomically: true, encoding: .utf8)
            printStatus = .success("ZPL exportiert: \(url.lastPathComponent)")
        } catch {
            printStatus = .failure("Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func prepareJob() async {
        guard printerValidation == .valid,
              let printerName = document.printSettings.selectedPrinterName else {
            printStatus = .failure(printerValidation.message ?? "Kein Drucker ausgewählt.")
            return
        }

        isPreparingJob = true
        defer { isPreparingJob = false }

        do {
            let job = try RawPrintJob.prepare(zpl: zpl, printerName: printerName)
            preparedJob = job
            printStatus = .success("Druckauftrag vorbereitet: \(job.zplFileURL.lastPathComponent)\n\(job.commandPreview)")
        } catch {
            preparedJob = nil
            printStatus = .failure("Druckauftrag konnte nicht vorbereitet werden: \(error.localizedDescription)")
        }
    }

    private func sendPreparedJob() async {
        if preparedJob == nil {
            await prepareJob()
        }

        guard let preparedJob else {
            return
        }

        isSendingPrintJob = true
        defer { isSendingPrintJob = false }

        do {
            let result = try await preparedJob.send()

            if result.didSucceed {
                printStatus = .success("Druckauftrag gesendet.\n\(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
            } else {
                printStatus = .failure(
                    """
                    Druck fehlgeschlagen (Exit \(result.exitCode)).
                    stdout: \(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
                    stderr: \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
                    """
                )
            }
        } catch {
            printStatus = .failure("Druck fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func printRangeValueBinding(
        for variable: VariableDefinition,
        keyPath: WritableKeyPath<PrintVariableRange, Int>
    ) -> Binding<Int> {
        Binding(
            get: { currentPrintRange(for: variable)[keyPath: keyPath] },
            set: { newValue in
                updatePrintRange(for: variable) { range in
                    range[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func currentPrintRange(for variable: VariableDefinition) -> PrintVariableRange {
        document.printSettings.range(for: variable) ?? PrintVariableRange(
            variableID: variable.id,
            variableName: variable.name,
            startValue: variable.startValue,
            endValue: max(variable.startValue, variable.endValue),
            copiesPerValue: 1
        )
    }

    private func updatePrintRange(
        for variable: VariableDefinition,
        update: (inout PrintVariableRange) -> Void
    ) {
        var range = currentPrintRange(for: variable)
        update(&range)
        range.variableName = variable.name
        range = range.clamped

        if let index = document.printSettings.variableRanges.firstIndex(where: { $0.variableID == variable.id }) {
            document.printSettings.variableRanges[index] = range
        } else {
            document.printSettings.variableRanges.append(range)
        }
    }

    private func statusLabel(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .lineLimit(2)
    }

    private func printStatusView(_ status: PrintWorkspaceStatus) -> some View {
        Label(status.message, systemImage: status.systemImage)
            .font(.system(size: 10, weight: .medium, design: .default))
            .foregroundStyle(status.color)
            .lineLimit(4)
            .textSelection(.enabled)
    }
}

private enum PrintWorkspaceStatus: Equatable {
    case info(String)
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .info(let message), .success(let message), .failure(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info:
            return .secondary
        case .success:
            return .green
        case .failure:
            return .red
        }
    }
}

private struct PrintControlPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))

            content
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: ZPrintDesign.Metric.panelCornerRadius, style: .continuous)
                .fill(ZPrintDesign.ColorToken.panelBackground.opacity(0.82))
        }
        .overlay {
            RoundedRectangle(cornerRadius: ZPrintDesign.Metric.panelCornerRadius, style: .continuous)
                .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
        }
    }
}

private struct PrintNumberControl: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)

            ZPrintNumberStepperField(
                title: title,
                value: $value,
                width: 92
            )
        }
    }
}

private struct SequencePrintControlCard: View {
    let variable: VariableDefinition
    @Binding var startValue: Int
    @Binding var endValue: Int
    @Binding var copiesPerValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(variable.chipTitle)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)

            HStack(spacing: 6) {
                PrintNumberControl(title: "Start", value: $startValue)
                PrintNumberControl(title: "Ende", value: $endValue)
                PrintNumberControl(title: "Anzahl", value: $copiesPerValue)
            }

            Text("Schritt \(max(1, variable.step))")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.62))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
        }
    }
}
