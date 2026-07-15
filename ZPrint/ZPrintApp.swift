//
//  ZPrintApp.swift
//  ZPrint
//
//  Created by Niklas Gabriel on 08.07.26.
//

import AppKit
import SwiftUI

@main
struct ZPrintApp: App {
    static let startWindowID = "zprint-start"

    @NSApplicationDelegateAdaptor(ZPrintApplicationDelegate.self) private var applicationDelegate
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
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            ZPrintCommands()
        }
    }
}

private final class ZPrintApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        installApplicationIcon()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installApplicationIcon()
    }

    private func installApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else {
            return
        }

        icon.isTemplate = false
        NSApplication.shared.applicationIconImage = icon
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
