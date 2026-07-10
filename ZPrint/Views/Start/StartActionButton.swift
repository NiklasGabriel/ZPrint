//
//  StartActionButton.swift
//  ZPrint
//

import SwiftUI

struct StartActionButton: View {
    let title: String
    let systemImage: String
    var isDisabled = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isDisabled ? .secondary.opacity(0.45) : ZPrintDesign.ColorToken.secondaryText)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isDisabled ? Color.secondary.opacity(0.45) : Color.primary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background {
                Capsule()
                    .fill(backgroundColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovering = $0 }
        .help(title)
    }

    private var backgroundColor: Color {
        if isDisabled {
            return ZPrintDesign.ColorToken.subtlePanelBackground.opacity(0.45)
        }

        return isHovering
            ? ZPrintDesign.ColorToken.hoverFill
            : ZPrintDesign.ColorToken.subtlePanelBackground
    }
}
