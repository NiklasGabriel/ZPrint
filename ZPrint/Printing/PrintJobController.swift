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

        return printerManager.printers.first?.name ?? selectedPrinterName
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
        let pdfDocument = highResolutionPDFDocument(from: document)
        let zpl = ZPLEngine.generateBatchZPL(document: pdfDocument)
        guard !zpl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = .failure("ZPL ist leer.")
            return
        }

        isRenderingPDF = true
        status = .info("ZPL wird als \(pdfDocument.label.dotsPerInch)-dpi-PDF gerendert ...")
        defer { isRenderingPDF = false }

        do {
            let pdfData = try await ZPLPDFRenderer.renderPDF(
                zpl: zpl,
                labelSize: pdfDocument.label
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

    private func highResolutionPDFDocument(from document: ZPrintDocument) -> ZPrintDocument {
        let targetDPI = min(max(document.label.dotsPerInch, 600), 600)
        let scale = Double(targetDPI) / Double(max(1, document.label.dotsPerInch))

        guard scale > 1 else {
            return document
        }

        var pdfDocument = document
        pdfDocument.label = scaledLabelSize(document.label, scale: scale, targetDPI: targetDPI)
        pdfDocument.elements = document.elements.map { scaledElement($0, scale: scale) }
        pdfDocument.guides = document.guides.map { guide in
            var scaledGuide = guide
            scaledGuide.positionDots = scaledDots(guide.positionDots, scale: scale, minimum: 0)
            return scaledGuide
        }
        return pdfDocument
    }

    private func scaledLabelSize(_ labelSize: LabelSize, scale: Double, targetDPI: Int) -> LabelSize {
        LabelSize(
            id: "\(labelSize.id)-pdf-\(targetDPI)dpi",
            name: "\(labelSize.name) PDF \(targetDPI) dpi",
            widthMillimeters: labelSize.widthMillimeters,
            heightMillimeters: labelSize.heightMillimeters,
            dotsPerInch: targetDPI,
            widthDots: scaledDots(labelSize.widthDots, scale: scale, minimum: 1),
            heightDots: scaledDots(labelSize.heightDots, scale: scale, minimum: 1),
            isFavorite: labelSize.isFavorite,
            isInStock: labelSize.isInStock
        )
    }

    private func scaledElement(_ element: LabelElement, scale: Double) -> LabelElement {
        switch element {
        case .text(var textElement):
            textElement.frame = scaledFrame(textElement.frame, scale: scale)
            textElement.fontSizeDots = scaledDots(textElement.fontSizeDots, scale: scale, minimum: 1)
            return .text(textElement)
        case .barcode(var barcodeElement):
            barcodeElement.frame = scaledFrame(barcodeElement.frame, scale: scale)
            barcodeElement.moduleWidth = scaledDots(barcodeElement.moduleWidth, scale: scale, minimum: 1)
            return .barcode(barcodeElement)
        case .shape(var shapeElement):
            shapeElement.frame = scaledFrame(shapeElement.frame, scale: scale)
            shapeElement.strokeWidthDots = scaledDots(shapeElement.strokeWidthDots, scale: scale, minimum: 1)
            return .shape(shapeElement)
        case .image(var imageElement):
            imageElement.frame = scaledFrame(imageElement.frame, scale: scale)
            return .image(imageElement)
        }
    }

    private func scaledFrame(_ frame: LabelElementFrame, scale: Double) -> LabelElementFrame {
        LabelElementFrame(
            xDots: Int((Double(frame.xDots) * scale).rounded()),
            yDots: Int((Double(frame.yDots) * scale).rounded()),
            widthDots: scaledDots(frame.widthDots, scale: scale, minimum: 1),
            heightDots: scaledDots(frame.heightDots, scale: scale, minimum: 1)
        )
    }

    private func scaledDots(_ dots: Int, scale: Double, minimum: Int) -> Int {
        max(minimum, Int((Double(dots) * scale).rounded()))
    }

    func prepareJob(for document: ZPrintDocument) async {
        isPreparingJob = true
        defer { isPreparingJob = false }

        do {
            let job = try makeFreshPrintJob(for: document)
            preparedJob = job
            status = .success("Druckauftrag vorbereitet.")
        } catch {
            preparedJob = nil
            status = .failure("Druckauftrag konnte nicht vorbereitet werden: \(error.localizedDescription)")
        }
    }

    func sendPrintJob(for document: ZPrintDocument) async {
        isSendingPrintJob = true
        defer { isSendingPrintJob = false }

        do {
            let job = try makeFreshPrintJob(for: document)
            preparedJob = job
            let result = try await job.send()

            if result.didSucceed {
                status = .success("Druckauftrag gesendet.")
            } else {
                let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                let message = stderr.isEmpty ? stdout : stderr
                status = .failure(
                    message.isEmpty
                        ? "Druck fehlgeschlagen (Exit \(result.exitCode))."
                        : "Druck fehlgeschlagen (Exit \(result.exitCode)): \(message)"
                )
            }
        } catch {
            status = .failure("Druck fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func makeFreshPrintJob(for document: ZPrintDocument) throws -> RawPrintJob {
        let validation = printerManager.validation(for: document.printSettings.selectedPrinterName)
        guard validation == .valid,
              let printerName = document.printSettings.selectedPrinterName else {
            throw PrintJobControllerError.validation(validation.message ?? "Kein Drucker ausgewählt.")
        }

        let zpl = ZPLEngine.generateBatchZPL(document: document)
        return try RawPrintJob.prepare(zpl: zpl, printerName: printerName)
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

private enum PrintJobControllerError: Error, LocalizedError {
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .validation(let message):
            return message
        }
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
