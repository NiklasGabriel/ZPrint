//
//  ZPrintWorkspaceView.swift
//  ZPrint
//

import SwiftUI

struct ZPrintWorkspaceView: View {
    @Binding var document: ZPrintDocument
    @Binding var selectedElementID: UUID?
    @Binding var selectedGuideID: UUID?
    @Binding var selectedVariableID: UUID?
    @Binding var previewContext: VariableEngine.Context
    @Binding var activeFormatPanePage: FormatPanePage
    @ObservedObject var printController: PrintJobController

    var body: some View {
        Group {
            switch document.viewSettings.mode {
            case .edit:
                EditorWorkspaceView(
                    document: $document,
                    selectedElementID: $selectedElementID,
                    selectedGuideID: $selectedGuideID,
                    selectedVariableID: $selectedVariableID,
                    activeFormatPanePage: $activeFormatPanePage
                )
            case .preview:
                PreviewWorkspaceView(
                    document: $document,
                    previewContext: $previewContext
                )
            case .print:
                PrintWorkspaceView(
                    document: $document,
                    printController: printController
                )
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
