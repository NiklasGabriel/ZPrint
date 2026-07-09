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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: ZPrintDesign.Metric.panelCornerRadius, style: .continuous)
                .fill(ZPrintDesign.ColorToken.panelBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: ZPrintDesign.Metric.panelCornerRadius, style: .continuous)
                .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.025), radius: 5, x: 0, y: 1)
    }
}
