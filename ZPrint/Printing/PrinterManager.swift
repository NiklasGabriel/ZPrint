//
//  PrinterManager.swift
//  ZPrint
//

import AppKit
import Combine
import Darwin
import Foundation

@MainActor
final class PrinterManager: ObservableObject {
    @Published private(set) var printers: [LocalPrinter] = []
    @Published private(set) var state: PrinterManagerState = .idle

    private let userDefaultsKey = "ZPrint.lastSelectedPrinterName"

    var lastSelectedPrinterName: String? {
        get { UserDefaults.standard.string(forKey: userDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: userDefaultsKey) }
    }

    func refreshPrinters() async {
        state = .loading

        do {
            let discoveredPrinters = try await Self.discoverPrinters()
            printers = discoveredPrinters
            state = discoveredPrinters.isEmpty ? .empty : .ready
        } catch {
            printers = []
            state = .failed(error.localizedDescription)
        }
    }

    func printer(named name: String?) -> LocalPrinter? {
        guard let name, !name.isEmpty else {
            return nil
        }

        return printers.first { $0.name == name }
    }

    func validation(for selectedPrinterName: String?) -> PrinterSelectionValidation {
        guard !printers.isEmpty else {
            return .noPrintersFound
        }

        guard let selectedPrinterName, !selectedPrinterName.isEmpty else {
            return .noPrinterSelected
        }

        guard printer(named: selectedPrinterName) != nil else {
            return .printerMissing(selectedPrinterName)
        }

        return .valid
    }

    private static func discoverPrinters() async throws -> [LocalPrinter] {
        let cupsPrinters = await cupsPrinters()
        if !cupsPrinters.isEmpty {
            return cupsPrinters
        }

        let fallbackPrinters = appKitPrinters()
        if !fallbackPrinters.isEmpty {
            return fallbackPrinters
        }

        let schedulerOutput = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/lpstat"),
            arguments: ["-r"]
        )
        let schedulerMessage = schedulerOutput?.combinedMessage.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        throw PrinterManagerError.commandFailed(
            schedulerMessage.isEmpty ? "Keine CUPS-Drucker gefunden." : schedulerMessage
        )
    }

    private static func cupsPrinters() async -> [LocalPrinter] {
        var printersByName: [String: LocalPrinter] = [:]

        if let destinationOutput = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/lpstat"),
            arguments: ["-e"]
        ),
           destinationOutput.exitCode == 0 {
            for name in destinationOutput.stdout
                .components(separatedBy: .newlines)
                .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                where !name.isEmpty {
                printersByName[name] = printersByName[name] ?? LocalPrinter(name: name)
            }
        }

        if let deviceOutput = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/lpstat"),
            arguments: ["-v"]
        ),
           deviceOutput.exitCode == 0 {
            for printer in parseDeviceOutput(deviceOutput.stdout) {
                var existingPrinter = printersByName[printer.name] ?? printer
                existingPrinter.deviceURI = printer.deviceURI
                printersByName[printer.name] = existingPrinter
            }
        }

        if let printerOutput = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/lpstat"),
            arguments: ["-p"]
        ),
           printerOutput.exitCode == 0 {
            for printer in parsePrinterStatusOutput(printerOutput.stdout) {
                printersByName[printer.name] = printersByName[printer.name] ?? printer
            }
        }

        return printersByName.values.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private static func appKitPrinters() -> [LocalPrinter] {
        NSPrinter.printerNames
            .map { LocalPrinter(name: $0, deviceURI: nil) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private static func parseLPStatOutput(_ output: String) -> [LocalPrinter] {
        var printersByName: [String: LocalPrinter] = [:]

        for line in output.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.hasPrefix("printer ") {
                let components = trimmedLine.components(separatedBy: .whitespaces)
                if components.count >= 2 {
                    let name = components[1]
                    printersByName[name] = printersByName[name] ?? LocalPrinter(name: name)
                }
            } else if trimmedLine.hasPrefix("device for ") {
                let prefix = "device for "
                let remainder = String(trimmedLine.dropFirst(prefix.count))
                let parts = remainder.split(separator: ":", maxSplits: 1)

                guard let rawName = parts.first else {
                    continue
                }

                let name = String(rawName)
                let deviceURI = parts.count > 1
                    ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    : nil
                var printer = printersByName[name] ?? LocalPrinter(name: name)
                printer.deviceURI = deviceURI
                printersByName[name] = printer
            }
        }

        return printersByName.values.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private static func parseDeviceOutput(_ output: String) -> [LocalPrinter] {
        output.components(separatedBy: .newlines).compactMap { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("device for ") else {
                return nil
            }

            let remainder = String(trimmedLine.dropFirst("device for ".count))
            let parts = remainder.split(separator: ":", maxSplits: 1)
            guard let rawName = parts.first else {
                return nil
            }

            return LocalPrinter(
                name: String(rawName),
                deviceURI: parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            )
        }
    }

    private static func parsePrinterStatusOutput(_ output: String) -> [LocalPrinter] {
        output.components(separatedBy: .newlines).compactMap { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("printer ") else {
                return nil
            }

            let components = trimmedLine.components(separatedBy: .whitespaces)
            guard components.count >= 2 else {
                return nil
            }

            return LocalPrinter(name: components[1], deviceURI: nil)
        }
    }
}

struct LocalPrinter: Identifiable, Equatable, Sendable {
    var name: String
    var deviceURI: String?

    var id: String { name }
    var displayName: String { name.replacingOccurrences(of: "_", with: " ") }
}

enum PrinterManagerState: Equatable {
    case idle
    case loading
    case ready
    case empty
    case failed(String)
}

enum PrinterSelectionValidation: Equatable {
    case valid
    case noPrintersFound
    case noPrinterSelected
    case printerMissing(String)

    var message: String? {
        switch self {
        case .valid:
            return nil
        case .noPrintersFound:
            return "Kein lokaler Drucker gefunden."
        case .noPrinterSelected:
            return "Kein Drucker ausgewählt."
        case .printerMissing(let name):
            return "Der ausgewählte Drucker „\(name)“ ist nicht mehr vorhanden."
        }
    }
}

enum PrinterManagerError: Error, LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message.isEmpty ? "Druckerliste konnte nicht gelesen werden." : message
        }
    }
}

struct ProcessOutput: Equatable, Sendable {
    var exitCode: Int32
    var stdout: String
    var stderr: String

    var combinedMessage: String {
        [stderr, stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

enum ProcessRunner {
    static func run(
        executableURL: URL,
        arguments: [String],
        standardInput: Data? = nil
    ) async throws -> ProcessOutput {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let stdinPipe: Pipe?
            if standardInput != nil {
                let pipe = Pipe()
                process.standardInput = pipe
                stdinPipe = pipe
            } else {
                stdinPipe = nil
            }

            try process.run()

            if let standardInput,
               let stdinPipe {
                signal(SIGPIPE, SIG_IGN)
                stdinPipe.fileHandleForWriting.write(standardInput)
                try? stdinPipe.fileHandleForWriting.close()
            }

            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            return ProcessOutput(
                exitCode: process.terminationStatus,
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )
        }
        .value
    }
}
