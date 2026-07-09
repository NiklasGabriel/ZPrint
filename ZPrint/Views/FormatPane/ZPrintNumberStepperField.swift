//
//  ZPrintNumberStepperField.swift
//  ZPrint
//

import SwiftUI

struct ZPrintNumberStepperField: View {
    let title: String
    @Binding var value: Int
    var step = 1
    var width: CGFloat = 116
    var isDisabled = false

    var body: some View {
        HStack(spacing: 0) {
            Button {
                value -= step
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)

            TextField(title, value: $value, format: .number)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .monospacedDigit()
                .frame(width: max(34, width - 52), height: 26)

            Button {
                value += step
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
        }
        .frame(width: width, height: 28)
        .background {
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.78))
        }
        .overlay {
            Capsule()
                .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .help(title)
    }
}
