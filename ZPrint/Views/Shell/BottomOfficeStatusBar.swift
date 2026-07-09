//
//  BottomOfficeStatusBar.swift
//  ZPrint
//

import SwiftUI

struct BottomOfficeStatusBar: View {
    @Binding var document: ZPrintDocument

    var body: some View {
        HStack(spacing: 10) {
            Label(document.label.name, systemImage: "tag")
                .labelStyle(.titleAndIcon)
            separator
            Text("\(document.label.dotsPerInch) dpi")
            separator
            Text("\(document.elements.count) Elemente")
            separator
            Label(document.viewSettings.mode.displayName, systemImage: document.viewSettings.mode.systemImageName)
                .labelStyle(.titleAndIcon)

            Spacer(minLength: 18)

            ZoomControl(zoomScale: zoomBinding)
                .frame(width: 228)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: ZPrintDesign.Metric.statusBarHeight)
        .background {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.panelBackground)
                .shadow(color: .black.opacity(0.035), radius: 5, x: 0, y: -1)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.softBorder)
                .frame(height: 1)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(ZPrintDesign.ColorToken.softBorder)
            .frame(width: 1, height: 14)
    }

    private var zoomBinding: Binding<Double> {
        Binding(
            get: { document.viewSettings.zoomScale },
            set: { document.viewSettings.zoomScale = min(max($0, 0.25), 3.0) }
        )
    }
}
