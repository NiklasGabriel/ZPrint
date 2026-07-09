//
//  ShapeFormatPane.swift
//  ZPrint
//

import SwiftUI

struct ShapeFormatPane: View {
    @Binding var element: ShapeLabelElement
    let labelSize: LabelSize
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatSection(title: "Form formatieren") {
                PropertyRow(title: "Form") {
                    Picker("Form", selection: $element.shape) {
                        Text("Rechteck").tag(LabelShapeKind.rectangle)
                        Text("Ellipse").tag(LabelShapeKind.ellipse)
                        Text("Linie").tag(LabelShapeKind.line)
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                IntegerPropertyField(title: "Linie", value: clampedBinding(\.strokeWidthDots, 1...40))
                Toggle("Gefüllt", isOn: $element.isFilled)
                    .controlSize(.small)
            }

            FormatSection(title: "Position") {
                IntegerPropertyField(title: "X", value: frameBinding(\.xDots))
                IntegerPropertyField(title: "Y", value: frameBinding(\.yDots))
                IntegerPropertyField(title: "Breite", value: frameBinding(\.widthDots, minimum: 1))
                IntegerPropertyField(title: "Höhe", value: frameBinding(\.heightDots, minimum: 1))
            }

            FormatSection(title: "Aktionen") {
                Button(role: .destructive, action: delete) {
                    Label("Form löschen", systemImage: "trash")
                }
                .controlSize(.small)
            }
        }
    }

    private func frameBinding(_ keyPath: WritableKeyPath<LabelElementFrame, Int>, minimum: Int = 0) -> Binding<Int> {
        Binding(
            get: { element.frame[keyPath: keyPath] },
            set: { newValue in
                var frame = element.frame
                frame[keyPath: keyPath] = max(minimum, newValue)
                element.frame = frame.clamped(to: labelSize)
            }
        )
    }

    private func clampedBinding(_ keyPath: WritableKeyPath<ShapeLabelElement, Int>, _ range: ClosedRange<Int>) -> Binding<Int> {
        Binding(
            get: { element[keyPath: keyPath] },
            set: { element[keyPath: keyPath] = min(max($0, range.lowerBound), range.upperBound) }
        )
    }
}
