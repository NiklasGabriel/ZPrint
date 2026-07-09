//
//  RecentProjectsView.swift
//  ZPrint
//

import SwiftUI

struct RecentProjectsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zuletzt verwendet")
                .font(.system(size: 17, weight: .semibold))

            VStack(spacing: 8) {
                RecentProjectRow(title: "Noch keine Projekte", subtitle: "DocumentGroup übernimmt Öffnen und Speichern")
            }

            Spacer()
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(ZPrintDesign.ColorToken.subtlePanelBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.softBorder)
                .frame(width: 1)
        }
    }
}

private struct RecentProjectRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(ZPrintDesign.ColorToken.accent.opacity(0.13))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "tag")
                        .foregroundStyle(ZPrintDesign.ColorToken.accent)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ZPrintDesign.ColorToken.panelBackground.opacity(0.55))
        }
    }
}
