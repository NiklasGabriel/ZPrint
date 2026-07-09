//
//  RibbonGroupView.swift
//  ZPrint
//

import SwiftUI

struct RibbonGroupView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .top, spacing: 6) {
                content
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(height: ZPrintDesign.Metric.ribbonContentHeight)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.18))
                .padding(.horizontal, 3)
                .padding(.vertical, 5)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.hairline)
                .frame(width: 1)
                .padding(.vertical, 8)
        }
    }
}
