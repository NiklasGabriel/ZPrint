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
    @State private var isHovering = false

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
            .frame(minWidth: title.isEmpty ? 30 : 0)
            .frame(height: ZPrintDesign.Metric.buttonHeight)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(buttonFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(buttonBorder, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .onHover { isHovering = $0 }
        .help(title)
    }

    private var buttonFill: Color {
        if isSelected {
            return ZPrintDesign.ColorToken.selectedFill
        }

        return isHovering ? ZPrintDesign.ColorToken.hoverFill : Color.clear
    }

    private var buttonBorder: Color {
        if isSelected {
            return ZPrintDesign.ColorToken.accent.opacity(0.34)
        }

        return isHovering ? ZPrintDesign.ColorToken.hairline : Color.clear
    }
}

struct RibbonLargeButton: View {
    let title: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void
    @State private var isHovering = false

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
                    .fill(isHovering ? ZPrintDesign.ColorToken.hoverFill : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isHovering ? ZPrintDesign.ColorToken.hairline : Color.clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .onHover { isHovering = $0 }
        .help(title)
    }
}
