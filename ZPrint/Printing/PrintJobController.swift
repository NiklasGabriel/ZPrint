//
//  PrintJobController.swift
//  ZPrint
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PrintJobController: ObservableObject {
    @Published var status: PrintJobStatus = .idle
    @Published var preparedJob: RawPrintJob?
    @Published var isPreparingJob = false
    @Published var isSendingPrintJob = false
    @Published var isRenderingPDF = false

    let printerManager = PrinterManager()
    private var cancellables: Set<AnyCancellable> = []

    init() {
        printerManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func refreshPrinters() async {
        await printerManager.refreshPrinters()
    }

    func preferredPrinterName(current selectedPrinterName: String?) -> String? {
        if let selectedPrinterName,
           printerManager.printer(named: selectedPrinterName) != nil {
            return selectedPrinterName
        }

        if let lastSelectedPrinterName = printerManager.lastSelectedPrinterName,
           printerManager.printer(named: lastSelectedPrinterName) != nil {
            return lastSelectedPrinterName
        }

        return selectedPrinterName
    }

    func selectedPrinterDidChange(_ printerName: String?) {
        printerManager.lastSelectedPrinterName = printerName
        preparedJob = nil
    }

    func copyZPL(for document: ZPrintDocument) {
        let zpl = ZPLEngine.generateBatchZPL(document: document)
        guard !zpl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = .failure("ZPL ist leer.")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(zpl, forType: .string)
        status = .success("ZPL wurde in die Zwischenablage kopiert.")
    }

    func exportZPL(for document: ZPrintDocument) {
        let zpl = ZPLEngine.generateBatchZPL(document: document)
        guard !zpl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = .failure("ZPL ist leer.")
            return
        }

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
            status = .success("ZPL exportiert: \(url.lastPathComponent)")
        } catch {
            status = .failure("Export fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func renderPDF(for document: ZPrintDocument) async {
        let zpl = ZPLEngine.generateBatchZPL(document: document)
        guard !zpl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = .failure("ZPL ist leer.")
            return
        }

        isRenderingPDF = true
        status = .info("ZPL wird als PDF gerendert ...")
        defer { isRenderingPDF = false }

        do {
            let pdfData = try await ZPLPDFRenderer.renderPDF(
                zpl: zpl,
                labelSize: document.label
            )
            let pdfURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(sanitizedFileName(document.documentName))-ZPL-Preview-\(UUID().uuidString)")
                .appendingPathExtension("pdf")
            try pdfData.write(to: pdfURL, options: [.atomic])
            NSWorkspace.shared.open(pdfURL)
            status = .success("ZPL-PDF geöffnet: \(pdfURL.lastPathComponent)")
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    func prepareJob(for document: ZPrintDocument) async {
        let validation = printerManager.validation(for: document.printSettings.selectedPrinterName)
        guard validation == .valid,
              let printerName = document.printSettings.selectedPrinterName else {
            status = .failure(validation.message ?? "Kein Drucker ausgewählt.")
            return
        }

        let zpl = ZPLEngine.generateBatchZPL(document: document)
        isPreparingJob = true
        defer { isPreparingJob = false }

        do {
            let job = try RawPrintJob.prepare(zpl: zpl, printerName: printerName)
            preparedJob = job
            status = .success("Druckauftrag vorbereitet.")
        } catch {
            preparedJob = nil
            status = .failure("Druckauftrag konnte nicht vorbereitet werden: \(error.localizedDescription)")
        }
    }

    func sendPrintJob(for document: ZPrintDocument) async {
        if preparedJob == nil {
            await prepareJob(for: document)
        }

        guard let preparedJob else {
            return
        }

        isSendingPrintJob = true
        defer { isSendingPrintJob = false }

        do {
            let result = try await preparedJob.send()

            if result.didSucceed {
                status = .success("Druckauftrag gesendet.")
            } else {
                status = .failure(
                    "Druck fehlgeschlagen (Exit \(result.exitCode)): \(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
                )
            }
        } catch {
            status = .failure("Druck fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func sanitizedFileName(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
            .union(.newlines)
        let sanitized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: invalidCharacters)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "ZPrint" : sanitized
    }
}

enum PrintJobStatus: Equatable {
    case idle
    case info(String)
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .idle:
            return "Bereit."
        case .info(let message), .success(let message), .failure(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            return "checkmark.circle"
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
        case .idle:
            return .secondary
        case .info:
            return .secondary
        case .success:
            return .green
        case .failure:
            return .red
        }
    }
}
