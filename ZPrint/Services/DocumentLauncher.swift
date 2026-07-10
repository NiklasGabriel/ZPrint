//
//  DocumentLauncher.swift
//  ZPrint
//

import AppKit
import UniformTypeIdentifiers

@MainActor
final class DocumentLauncher {
    static let shared = DocumentLauncher()

    private init() {}

    func createNewDocument(completion: ((Bool) -> Void)? = nil) {
        NSDocumentController.shared.newDocument(nil)
        completion?(true)
    }

    func openDocument(completion: ((Bool) -> Void)? = nil) {
        let openPanel = NSOpenPanel()
        openPanel.title = "ZPrint-Projekt öffnen"
        openPanel.prompt = "Öffnen"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.zprint]

        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else {
                completion?(false)
                return
            }

            self.openDocument(at: url, completion: completion)
        }
    }

    func openRecentProject(_ project: RecentProject, completion: ((Bool) -> Void)? = nil) {
        guard project.exists else {
            showOpenError(
                ZPrintOpenError.missingRecentFile,
                url: project.url,
                recoverySuggestion: "Entferne den Eintrag aus „Zuletzt verwendet“ oder wähle die Datei erneut über „Bestehendes Projekt öffnen ...“."
            )
            completion?(false)
            return
        }

        let scopedResource = project.startAccessingSecurityScopedResource()
        openDocument(
            at: scopedResource.url,
            shouldRecordRecent: project.hasSecurityScopedBookmark,
            showsOpenError: false
        ) { didOpen in
            if scopedResource.didStartAccessing {
                scopedResource.url.stopAccessingSecurityScopedResource()
            }

            if !didOpen {
                if project.hasSecurityScopedBookmark {
                    self.showOpenError(ZPrintOpenError.recentOpenFailed, url: project.url)
                } else {
                    self.showOpenError(
                        ZPrintOpenError.missingSecurityScope,
                        url: project.url,
                        recoverySuggestion: "Bitte öffne die Datei einmal über „Bestehendes Projekt öffnen ...“. Danach speichert ZPrint den macOS-Zugriff für diesen Recent-Eintrag."
                    )
                }
            }

            completion?(didOpen)
        }
    }

    func openDocument(at url: URL, completion: ((Bool) -> Void)? = nil) {
        openDocument(at: url, shouldRecordRecent: true, completion: completion)
    }

    private func openDocument(
        at url: URL,
        shouldRecordRecent: Bool,
        showsOpenError: Bool = true,
        completion: ((Bool) -> Void)? = nil
    ) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error {
                if showsOpenError {
                    self.showOpenError(error, url: url)
                }
                completion?(false)
                return
            }

            if shouldRecordRecent {
                RecentProjectsStore.shared.record(url)
            }
            completion?(true)
        }
    }

    func showStartScreen() {
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOpenError(_ error: Error, url: URL) {
        showOpenError(error, url: url, recoverySuggestion: nil)
    }

    private func showOpenError(_ error: Error, url: URL, recoverySuggestion: String?) {
        let alert = NSAlert(error: error)
        alert.messageText = "Projekt konnte nicht geöffnet werden"
        alert.informativeText = [
            "\(url.lastPathComponent) konnte nicht als ZPrint-Projekt geöffnet werden.",
            error.localizedDescription,
            recoverySuggestion
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
        alert.runModal()
    }
}

private enum ZPrintOpenError: LocalizedError {
    case missingRecentFile
    case missingSecurityScope
    case recentOpenFailed

    var errorDescription: String? {
        switch self {
        case .missingRecentFile:
            return "Die Datei ist nicht mehr vorhanden."
        case .missingSecurityScope:
            return "ZPrint hat für diesen alten Recent-Eintrag noch keinen gespeicherten macOS-Dateizugriff."
        case .recentOpenFailed:
            return "Der gespeicherte Dateizugriff konnte nicht erneut verwendet werden."
        }
    }
}
