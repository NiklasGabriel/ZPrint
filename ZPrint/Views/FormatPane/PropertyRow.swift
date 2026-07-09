//
//  PropertyRow.swift
//  ZPrint
//

import SwiftUI

struct PropertyRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 86, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 24)
    }
}

struct PropertyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        PropertyRow(title: title) {
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}

struct IntegerPropertyField: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        PropertyRow(title: title) {
            ZPrintNumberStepperField(
                title: title,
                value: $value,
                width: 116
            )
        }
    }
}
