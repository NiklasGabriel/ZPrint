//
//  OfficeTitleBarView.swift
//  ZPrint
//

import SwiftUI

struct OfficeTitleBarView: View {
    @Binding var document: ZPrintDocument
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 10) {
            Spacer()

            modeBadge

            homeButton
                .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity)
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

    private var homeButton: some View {
        Button {
            DocumentLauncher.shared.showStartScreen()
            openWindow(id: ZPrintApp.startWindowID)
        } label: {
            Image(systemName: "house")
                .font(.system(size: 13, weight: .regular))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
        .help("Startbildschirm anzeigen")
    }

    private var modeBadge: some View {
        Label(document.viewSettings.mode.displayName, systemImage: document.viewSettings.mode.systemImageName)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .padding(.vertical, 4)
    }
}
