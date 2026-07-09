//
//  RawPrintJob.swift
//  ZPrint
//

import Foundation

struct RawPrintJob: Equatable, Sendable {
    var printerName: String
    var zplFileURL: URL
    var commandPreview: String

    static func prepare(
        zpl: String,
        printerName: String
    ) throws -> RawPrintJob {
        let trimmedZPL = zpl.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedZPL.isEmpty else {
            throw RawPrintJobError.emptyZPL
        }

        guard !printerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RawPrintJobError.missingPrinter
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZPrint-\(UUID().uuidString)")
            .appendingPathExtension("zpl")
        try zpl.write(to: fileURL, atomically: true, encoding: .utf8)

        return RawPrintJob(
            printerName: printerName,
            zplFileURL: fileURL,
            commandPreview: "/usr/bin/lp -d \(shellEscaped(printerName)) -o raw \(shellEscaped(fileURL.path))"
        )
    }

    func send() async throws -> RawPrintResult {
        let output = try await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/lp"),
            arguments: ["-d", printerName, "-o", "raw", zplFileURL.path]
        )

        return RawPrintResult(
            exitCode: output.exitCode,
            stdout: output.stdout,
            stderr: output.stderr
        )
    }

    private static func shellEscaped(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

struct RawPrintResult: Equatable, Sendable {
    var exitCode: Int32
    var stdout: String
    var stderr: String

    var didSucceed: Bool {
        exitCode == 0
    }
}

enum RawPrintJobError: Error, LocalizedError {
    case emptyZPL
    case missingPrinter

    var errorDescription: String? {
        switch self {
        case .emptyZPL:
            return "Der ZPL-Inhalt ist leer."
        case .missingPrinter:
            return "Es ist kein Drucker ausgewählt."
        }
    }
}
