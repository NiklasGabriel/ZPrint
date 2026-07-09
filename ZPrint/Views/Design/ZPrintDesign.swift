//
//  ZPrintDesign.swift
//  ZPrint
//

import SwiftUI

enum ZPrintDesign {
    enum ColorToken {
        static let appBackground = Color(nsColor: .windowBackgroundColor)
        static let workspaceBackground = Color(nsColor: .underPageBackgroundColor)
        static let ribbonBackground = Color(nsColor: .controlBackgroundColor)
        static let panelBackground = Color(nsColor: .textBackgroundColor)
        static let subtlePanelBackground = Color(nsColor: .controlBackgroundColor).opacity(0.72)
        static let border = Color(nsColor: .separatorColor).opacity(0.62)
        static let softBorder = Color(nsColor: .separatorColor).opacity(0.36)
        static let secondaryText = Color(nsColor: .secondaryLabelColor)
        static let accent = Color.accentColor
    }

    enum Metric {
        static let titleBarHeight: CGFloat = 42
        static let ribbonTabHeight: CGFloat = 31
        static let ribbonContentHeight: CGFloat = 96
        static let statusBarHeight: CGFloat = 30
        static let formatPaneWidth: CGFloat = 318
        static let cornerRadius: CGFloat = 8
        static let panelCornerRadius: CGFloat = 10
        static let spacing: CGFloat = 10
        static let compactSpacing: CGFloat = 6
        static let buttonHeight: CGFloat = 28
        static let largeRibbonButtonWidth: CGFloat = 68
    }
}
