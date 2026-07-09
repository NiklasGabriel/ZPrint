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
        static let subtlePanelBackground = Color(nsColor: .controlBackgroundColor).opacity(0.76)
        static let border = Color(nsColor: .separatorColor).opacity(0.62)
        static let softBorder = Color(nsColor: .separatorColor).opacity(0.36)
        static let hairline = Color(nsColor: .separatorColor).opacity(0.20)
        static let hoverFill = Color(nsColor: .selectedControlColor).opacity(0.08)
        static let selectedFill = Color.accentColor.opacity(0.13)
        static let secondaryText = Color(nsColor: .secondaryLabelColor)
        static let accent = Color.accentColor
    }

    enum Metric {
        static let titleBarHeight: CGFloat = 44
        static let ribbonTabHeight: CGFloat = 31
        static let ribbonContentHeight: CGFloat = 98
        static let statusBarHeight: CGFloat = 32
        static let formatPaneWidth: CGFloat = 326
        static let cornerRadius: CGFloat = 8
        static let panelCornerRadius: CGFloat = 9
        static let spacing: CGFloat = 10
        static let compactSpacing: CGFloat = 6
        static let buttonHeight: CGFloat = 30
        static let largeRibbonButtonWidth: CGFloat = 72
    }
}
