//
//  ZoomControl.swift
//  ZPrint
//

import SwiftUI

struct ZoomControl: View {
    @Binding var zoomScale: Double

    var body: some View {
        HStack(spacing: 6) {
            Button {
                zoomScale = max(0.25, zoomScale - 0.10)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Verkleinern")

            Slider(value: $zoomScale, in: 0.25...3.0, step: 0.05)
                .frame(width: 94)

            Text(zoomText)
                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)

            Button {
                zoomScale = min(3.0, zoomScale + 0.10)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Vergrößern")
        }
        .controlSize(.mini)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background {
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.76))
        }
        .overlay {
            Capsule()
                .stroke(ZPrintDesign.ColorToken.hairline, lineWidth: 1)
        }
        .help("Zoom")
    }

    private var zoomText: String {
        "\(Int((zoomScale * 100).rounded()))%"
    }
}
