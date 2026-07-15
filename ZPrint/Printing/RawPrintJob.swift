//
//  RawPrintJob.swift
//  ZPrint
//

import Foundation

struct RawPrintJob: Equatable, Sendable {
    var printerName: String
    var zplFileURL: URL
    var zplData: Data
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

        let zplData = Data(zpl.utf8)

        return RawPrintJob(
            printerName: printerName,
            zplFileURL: fileURL,
            zplData: zplData,
            commandPreview: "/usr/bin/lp -d \(shellEscaped(printerName)) -o raw \(shellEscaped(fileURL.path))"
        )
    }

    func send() async throws -> RawPrintResult {
        let commands = availablePrintCommands(for: printerName)

        guard !commands.isEmpty else {
            throw RawPrintJobError.printCommandUnavailable
        }

        var failedOutputs: [String] = []
        var lastOutput: ProcessOutput?

        for command in commands {
            do {
                let output = try await ProcessRunner.run(
                    executableURL: command.executableURL,
                    arguments: command.arguments,
                    standardInput: command.usesStandardInput ? zplData : nil
                )

                if output.exitCode == 0 {
                    return RawPrintResult(
                        exitCode: output.exitCode,
                        stdout: output.stdout,
                        stderr: output.stderr
                    )
                }

                lastOutput = output
                failedOutputs.append(command.failureSummary(for: output))
            } catch {
                failedOutputs.append("\(command.displayName): \(error.localizedDescription)")
            }
        }

        return RawPrintResult(
            exitCode: lastOutput?.exitCode ?? 1,
            stdout: lastOutput?.stdout ?? "",
            stderr: failedOutputs.joined(separator: "\n")
        )
    }

    private static func shellEscaped(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func availablePrintCommands(for printerName: String) -> [RawPrintCommand] {
        [
            RawPrintCommand(
                displayName: "lp",
                executableURL: URL(fileURLWithPath: "/usr/bin/lp"),
                arguments: ["-d", printerName, "-o", "raw", Self.zplFileArgumentPlaceholder],
                usesStandardInput: false
            ),
            RawPrintCommand(
                displayName: "lpr",
                executableURL: URL(fileURLWithPath: "/usr/bin/lpr"),
                arguments: ["-P", printerName, "-l", Self.zplFileArgumentPlaceholder],
                usesStandardInput: false
            ),
            RawPrintCommand(
                displayName: "lp stdin",
                executableURL: URL(fileURLWithPath: "/usr/bin/lp"),
                arguments: ["-d", printerName, "-o", "raw"],
                usesStandardInput: true
            ),
            RawPrintCommand(
                displayName: "lpr stdin",
                executableURL: URL(fileURLWithPath: "/usr/bin/lpr"),
                arguments: ["-P", printerName, "-l"],
                usesStandardInput: true
            )
        ]
        .map { command in
            command.replacingFilePlaceholder(with: zplFileURL.path)
        }
        .filter { FileManager.default.isExecutableFile(atPath: $0.executableURL.path) }
    }

    fileprivate static let zplFileArgumentPlaceholder = "__ZPRINT_ZPL_FILE__"
}

private struct RawPrintCommand: Equatable, Sendable {
    var displayName: String
    var executableURL: URL
    var arguments: [String]
    var usesStandardInput: Bool

    func replacingFilePlaceholder(with path: String) -> RawPrintCommand {
        RawPrintCommand(
            displayName: displayName,
            executableURL: executableURL,
            arguments: arguments.map { $0 == RawPrintJob.zplFileArgumentPlaceholder ? path : $0 },
            usesStandardInput: usesStandardInput
        )
    }

    func failureSummary(for output: ProcessOutput) -> String {
        let stderr = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let stdout = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = stderr.isEmpty ? stdout : stderr
        return detail.isEmpty
            ? "\(displayName): Exit \(output.exitCode)"
            : "\(displayName): Exit \(output.exitCode): \(detail)"
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
    case printCommandUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyZPL:
            return "Der ZPL-Inhalt ist leer."
        case .missingPrinter:
            return "Es ist kein Drucker ausgewählt."
        case .printCommandUnavailable:
            return "Weder /usr/bin/lp noch /usr/bin/lpr ist verfügbar. Raw-Druck kann nicht gestartet werden."
        }
    }
}
