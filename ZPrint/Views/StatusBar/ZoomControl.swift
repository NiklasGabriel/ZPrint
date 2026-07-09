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
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)

            Slider(value: $zoomScale, in: 0.25...3.0, step: 0.05)
                .frame(width: 96)

            Text(zoomText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            Button {
                zoomScale = min(3.0, zoomScale + 0.10)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
        }
        .controlSize(.mini)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        }
        .help("Zoom")
    }

    private var zoomText: String {
        "\(Int((zoomScale * 100).rounded()))%"
    }
}
