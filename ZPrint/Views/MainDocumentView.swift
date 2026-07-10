//
//  MainDocumentView.swift
//  ZPrint
//

import AppKit
import SwiftUI

struct MainDocumentView: View {
    @Binding var document: ZPrintDocument
    let fileURL: URL?

    @State private var selectedElementID: UUID?
    @State private var selectedGuideID: UUID?
    @State private var pendingFileRenameTask: Task<Void, Never>?
    @State private var nsDocument: NSDocument?
    @State private var knownFileURL: URL?
    @State private var isSynchronizingDocumentName = false

    var body: some View {
        AppShellView(
            document: $document,
            documentTitle: documentTitleBinding,
            isFileBackedDocument: knownFileURL != nil,
            selectedElementID: $selectedElementID,
            selectedGuideID: $selectedGuideID
        )
        .frame(minWidth: 1100, minHeight: 660)
        .background(ZPrintDesign.ColorToken.appBackground)
        .background(
            WindowChromeConfigurator(
                title: document.documentName,
                representedURL: knownFileURL ?? fileURL
            )
            .frame(width: 0, height: 0)
        )
        .background {
            DocumentWindowAccessor { resolvedDocument in
                nsDocument = resolvedDocument
                if let resolvedURL = resolvedDocument?.fileURL {
                    synchronizeDocumentName(with: resolvedURL)
                }
            }
            .frame(width: 0, height: 0)
        }
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            synchronizeDocumentName(with: fileURL)
        }
        .onChange(of: fileURL) { _, newURL in
            synchronizeDocumentName(with: newURL)
        }
    }

    private var documentTitleBinding: Binding<String> {
        Binding(
            get: { document.documentName },
            set: { newName in
                updateDocumentTitle(to: newName)
            }
        )
    }

    private func updateDocumentTitle(to newName: String) {
        document.documentName = newName

        guard !isSynchronizingDocumentName,
              knownFileURL != nil || nsDocument?.fileURL != nil else {
            return
        }

        scheduleFileRename(to: newName)
    }

    private func scheduleFileRename(to documentName: String) {
        pendingFileRenameTask?.cancel()
        pendingFileRenameTask = Task {
            try? await Task.sleep(for: .milliseconds(700))

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                renameCurrentDocumentFile(to: documentName)
            }
        }
    }

    private func renameCurrentDocumentFile(to documentName: String) {
        guard let nsDocument = nsDocument,
              let currentURL = nsDocument.fileURL ?? knownFileURL,
              !documentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let sanitizedName = sanitizedFileName(from: documentName)
        guard !sanitizedName.isEmpty else {
            synchronizeDocumentName(with: currentURL)
            return
        }

        let fileExtension = currentURL.pathExtension.isEmpty ? "zprint" : currentURL.pathExtension
        let newURL = currentURL
            .deletingLastPathComponent()
            .appendingPathComponent(sanitizedName)
            .appendingPathExtension(fileExtension)

        guard newURL != currentURL else {
            synchronizeDocumentName(with: currentURL)
            return
        }

        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            NSSound.beep()
            synchronizeDocumentName(with: currentURL)
            return
        }

        nsDocument.move(to: newURL) { error in
            Task { @MainActor in
                if error == nil {
                    synchronizeDocumentName(with: newURL)
                } else {
                    NSSound.beep()
                    synchronizeDocumentName(with: currentURL)
                }
            }
        }
    }

    private func synchronizeDocumentName(with url: URL?) {
        guard let url else {
            knownFileURL = nil
            return
        }

        knownFileURL = url
        let fileName = url.deletingPathExtension().lastPathComponent
        guard !fileName.isEmpty, document.documentName != fileName else {
            return
        }

        isSynchronizingDocumentName = true
        document.documentName = fileName
        isSynchronizingDocumentName = false
    }

    private func sanitizedFileName(from name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalidCharacters = CharacterSet(charactersIn: "/:")
            .union(.newlines)

        return trimmedName
            .components(separatedBy: invalidCharacters)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
