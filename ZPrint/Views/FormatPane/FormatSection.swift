//
//  FormatSection.swift
//  ZPrint
//

import SwiftUI

struct FormatSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: ZPrintDesign.Metric.panelCornerRadius, style: .continuous)
                .fill(ZPrintDesign.ColorToken.panelBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: ZPrintDesign.Metric.panelCornerRadius, style: .continuous)
                .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
        }
    }
}
