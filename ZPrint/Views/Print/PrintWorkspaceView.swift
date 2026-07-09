//
//  PrintWorkspaceView.swift
//  ZPrint
//

import SwiftUI

struct PrintWorkspaceView: View {
    let document: ZPrintDocument

    var body: some View {
        ZPrintModePlaceholderView(
            title: "Drucken",
            systemImageName: "printer",
            document: document
        )
    }
}
