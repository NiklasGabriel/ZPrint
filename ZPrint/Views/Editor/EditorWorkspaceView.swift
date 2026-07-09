//
//  EditorWorkspaceView.swift
//  ZPrint
//

import SwiftUI

struct EditorWorkspaceView: View {
    @Binding var document: ZPrintDocument
    @Binding var selectedElementID: UUID?
    @Binding var selectedGuideID: UUID?
    @Binding var selectedVariableID: UUID?
    @Binding var activeFormatPanePage: FormatPanePage

    var body: some View {
        LabelCanvasView(
            document: $document,
            selectedElementID: $selectedElementID,
            selectedGuideID: $selectedGuideID,
            selectedVariableID: $selectedVariableID,
            activeFormatPanePage: $activeFormatPanePage
        )
    }
}
