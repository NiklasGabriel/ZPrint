//
//  ZPrintApp.swift
//  ZPrint
//
//  Created by Niklas Gabriel on 08.07.26.
//

import SwiftUI

@main
struct ZPrintApp: App {
    static let startWindowID = "zprint-start"

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("ZPrint", id: Self.startWindowID) {
            StartScreenView()
        }
        .defaultSize(width: 980, height: 620)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            ZPrintCommands()
        }

        DocumentGroup(newDocument: ZPrintDocument()) { file in
            MainDocumentView(
                document: file.$document,
                fileURL: file.fileURL
            )
        }
        .defaultSize(width: 1280, height: 820)
        .defaultLaunchBehavior(.suppressed)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            ZPrintCommands()
        }
    }
}

private struct ZPrintCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Neues Label") {
                DocumentLauncher.shared.createNewDocument()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Projekt öffnen ...") {
                DocumentLauncher.shared.openDocument()
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(after: .windowList) {
            Button("Startbildschirm anzeigen") {
                DocumentLauncher.shared.showStartScreen()
                openWindow(id: ZPrintApp.startWindowID)
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
        }
    }
}
