//
//  ZPrintStatusBar.swift
//  ZPrint
//

import SwiftUI

struct ZPrintStatusBar: View {
    @Binding var document: ZPrintDocument

    var body: some View {
        HStack(spacing: 10) {
            Label(document.label.name, systemImage: "rectangle")
                .labelStyle(.titleAndIcon)
            Divider()
                .frame(height: 14)
            Text("\(document.label.dotsPerInch) dpi")
            Divider()
                .frame(height: 14)
            Text("\(document.elements.count) Elemente")

            Spacer(minLength: 16)

            ZoomControl(zoomScale: zoomBinding)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(.bar)
    }

    private var zoomBinding: Binding<Double> {
        Binding(
            get: { document.viewSettings.zoomScale },
            set: { document.viewSettings.zoomScale = min(max($0, 0.25), 3.0) }
        )
    }
}
