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
            TextField("Dokumentname", text: $documentTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(width: 360)

            HStack {
                Spacer()
                    .frame(width: 96)

                Spacer()

                Label(document.viewSettings.mode.displayName, systemImage: document.viewSettings.mode.systemImageName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(ZPrintDesign.ColorToken.subtlePanelBackground)
                    }
            }
            .padding(.trailing, 14)
        }
        .frame(height: ZPrintDesign.Metric.titleBarHeight)
        .background(ZPrintDesign.ColorToken.panelBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.softBorder)
                .frame(height: 1)
        }
    }
}
