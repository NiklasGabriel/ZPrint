//
//  ZPrintModePlaceholderView.swift
//  ZPrint
//

import SwiftUI

struct ZPrintModePlaceholderView: View {
    let title: String
    let systemImageName: String
    let document: ZPrintDocument

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 18) {
                    workspaceHeader
                        .frame(maxWidth: 760)

                    labelSurface
                }
                .padding(.horizontal, 42)
                .padding(.vertical, 32)
                .frame(
                    minWidth: proxy.size.width,
                    minHeight: proxy.size.height,
                    alignment: .center
                )
            }
            .background(Color(nsColor: .underPageBackgroundColor))
        }
    }

    private var workspaceHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImageName)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Spacer()

            Text(document.label.displayName)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var labelSurface: some View {
        let baseWidth = min(max(Double(document.label.widthDots), 360), 680)
        let ratio = Double(document.label.heightDots) / Double(document.label.widthDots)
        let width = baseWidth * document.viewSettings.zoomScale
        let height = width * ratio

        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                Text(document.documentName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(12)
            }
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}
