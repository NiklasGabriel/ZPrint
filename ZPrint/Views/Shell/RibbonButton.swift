//
//  RibbonButton.swift
//  ZPrint
//

import SwiftUI

struct RibbonButton: View {
    let title: String
    let systemImage: String
    var isSelected = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(height: ZPrintDesign.Metric.buttonHeight)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? ZPrintDesign.ColorToken.accent.opacity(0.14) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? ZPrintDesign.ColorToken.accent.opacity(0.34) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .help(title)
    }
}

struct RibbonLargeButton: View {
    let title: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .frame(height: 26)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: ZPrintDesign.Metric.largeRibbonButtonWidth, height: 62)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .help(title)
    }
}
