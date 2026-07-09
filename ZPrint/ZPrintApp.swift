//
//  ZPrintApp.swift
//  ZPrint
//
//  Created by Niklas Gabriel on 08.07.26.
//

import SwiftUI

@main
struct ZPrintApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ZPrintDocument()) { file in
            MainDocumentView(
                document: file.$document,
                fileURL: file.fileURL
            )
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}
