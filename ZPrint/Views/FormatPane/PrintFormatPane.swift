//
//  PrintFormatPane.swift
//  ZPrint
//

import SwiftUI

struct PrintFormatPane: View {
    @Binding var document: ZPrintDocument
    @ObservedObject var printController: PrintJobController

    private var zpl: String {
        ZPLEngine.generateBatchZPL(document: document)
    }

    private var zplDiagnostics: [ZPLDiagnostic] {
        ZPLEngine.diagnostics(for: document)
    }

    private var runningVariable: VariableDefinition? {
        document.printSettings.runningVariable(in: document.variables)
    }

    private var runningRange: PrintVariableRange? {
        document.printSettings.runningRange(for: document.variables)
    }

    private var expectedLabelCount: Int {
        VariableEngine.batchContexts(for: document).count
    }

    private var printerValidation: PrinterSelectionValidation {
        printController.printerManager.validation(for: document.printSettings.selectedPrinterName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            printerSection
            jobSection
            zplPreviewSection
            statusSection
        }
        .task {
            await printController.refreshPrinters()
            let preferredPrinterName = printController.preferredPrinterName(
                current: document.printSettings.selectedPrinterName
            )
            if preferredPrinterName != document.printSettings.selectedPrinterName {
                document.printSettings.selectedPrinterName = preferredPrinterName
            }
        }
        .onChange(of: document.printSettings.selectedPrinterName) { _, newValue in
            printController.selectedPrinterDidChange(newValue)
        }
        .onChange(of: zpl) { _, _ in
            printController.preparedJob = nil
        }
    }

    private var printerSection: some View {
        FormatSection(title: "Drucker") {
            Picker("Drucker", selection: selectedPrinterBinding) {
                Text("Drucker wählen").tag("")

                ForEach(printController.printerManager.printers) { printer in
                    Text(printer.displayName).tag(printer.name)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .disabled(printController.printerManager.state == .loading || printController.printerManager.printers.isEmpty)

            HStack(spacing: 8) {
                printerStateLabel

                Spacer()

                Button {
                    Task {
                        await printController.refreshPrinters()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Drucker neu laden")
            }

            if let selectedPrinter = printController.printerManager.printer(named: document.printSettings.selectedPrinterName),
               let deviceURI = selectedPrinter.deviceURI {
                Text(deviceURI)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private var printerStateLabel: some View {
        switch printController.printerManager.state {
        case .idle:
            Label("Noch nicht geladen", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        case .loading:
            Label("Drucker werden geladen", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        case .ready:
            if let message = printerValidation.message {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Label("Drucker bereit", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        case .empty:
            Label("Kein Drucker gefunden", systemImage: "printer.slash")
                .foregroundStyle(.orange)
        case .failed(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }

    private var jobSection: some View {
        FormatSection(title: "Auftrag") {
            PropertyValueRow(title: "Laufvariable", value: runningVariable?.name ?? "-")
            PropertyValueRow(title: "Start", value: "\(runningRange?.startValue ?? document.printSettings.counterStart)")
            PropertyValueRow(title: "Ende", value: "\(runningRange?.endValue ?? document.printSettings.counterEnd)")
            PropertyValueRow(title: "Je Wert", value: "\(runningRange?.copiesPerValue ?? document.printSettings.copiesPerNumber)")
            PropertyValueRow(title: "Labels", value: "\(expectedLabelCount)")
        }
    }

    private var zplPreviewSection: some View {
        FormatSection(title: "ZPL-Vorschau") {
            ScrollView([.vertical, .horizontal]) {
                Text(zplPreview)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(8)
            }
            .frame(height: 132)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
            }

            Button {
                printController.copyZPL(for: document)
            } label: {
                Label("Vollständig kopieren", systemImage: "doc.on.doc")
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    private var statusSection: some View {
        FormatSection(title: "Status") {
            Label(printController.status.message, systemImage: printController.status.systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(printController.status.color)
                .fixedSize(horizontal: false, vertical: true)

            if let message = printerValidation.message {
                Label(message, systemImage: "printer.slash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(zplDiagnostics) { diagnostic in
                Label(
                    diagnostic.message,
                    systemImage: diagnostic.level == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(diagnostic.level == .error ? .red : .orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var selectedPrinterBinding: Binding<String> {
        Binding(
            get: { document.printSettings.selectedPrinterName ?? "" },
            set: { newValue in
                document.printSettings.selectedPrinterName = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private var zplPreview: String {
        let lines = zpl.components(separatedBy: .newlines)
        let previewLines = lines.prefix(34)
        let suffix = lines.count > previewLines.count ? "\n..." : ""
        return previewLines.joined(separator: "\n") + suffix
    }
}
