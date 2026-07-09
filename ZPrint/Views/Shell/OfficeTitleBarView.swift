//
//  OfficeTitleBarView.swift
//  ZPrint
//

import SwiftUI

struct OfficeTitleBarView: View {
    @Binding var document: ZPrintDocument
    @Binding var documentTitle: String

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ZPrintDesign.ColorToken.accent)

                TextField("Dokumentname", text: $documentTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(width: 300)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.54))
            }
            .overlay {
                Capsule()
                    .stroke(ZPrintDesign.ColorToken.hairline, lineWidth: 1)
            }
            .help("Dokumenttitel")

            HStack {
                Spacer()
                    .frame(width: 96)

                Spacer()

                Label(document.viewSettings.mode.displayName, systemImage: document.viewSettings.mode.systemImageName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(ZPrintDesign.ColorToken.subtlePanelBackground)
                    }
                    .overlay {
                        Capsule()
                            .stroke(ZPrintDesign.ColorToken.hairline, lineWidth: 1)
                    }
            }
            .padding(.trailing, 14)
        }
        .frame(height: ZPrintDesign.Metric.titleBarHeight)
        .background {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.panelBackground)
                .shadow(color: .black.opacity(0.045), radius: 8, x: 0, y: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.softBorder)
                .frame(height: 1)
        }
    }
}
