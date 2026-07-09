//
//  BottomOfficeStatusBar.swift
//  ZPrint
//

import SwiftUI

struct BottomOfficeStatusBar: View {
    @Binding var document: ZPrintDocument

    var body: some View {
        HStack(spacing: 12) {
            Text(document.label.name)
            separator
            Text("\(document.label.dotsPerInch) dpi")
            separator
            Text("\(document.elements.count) Elemente")
            separator
            Label(document.viewSettings.mode.displayName, systemImage: document.viewSettings.mode.systemImageName)
                .labelStyle(.titleAndIcon)

            Spacer(minLength: 18)

            ZoomControl(zoomScale: zoomBinding)
                .frame(width: 240)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: ZPrintDesign.Metric.statusBarHeight)
        .background(ZPrintDesign.ColorToken.panelBackground)
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
