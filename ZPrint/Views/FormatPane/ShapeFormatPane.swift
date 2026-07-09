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
                        ForEach(LabelShapeKind.allCases, id: \.self) { shape in
                            Text(shape.displayName)
                                .tag(shape)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                Toggle("Rahmen", isOn: $element.hasStroke)
                    .controlSize(.small)
                    .disabled(element.shape == .line)
                    .opacity(element.shape == .line ? 0.45 : 1)

                IntegerPropertyField(title: "Rahmenstärke", value: clampedBinding(\.strokeWidthDots, 1...40))

                PropertyRow(title: "Rahmenfarbe") {
                    ColorPicker("", selection: colorBinding(\.strokeColor), supportsOpacity: true)
                        .labelsHidden()
                        .controlSize(.small)
                }

                Toggle("Füllung", isOn: $element.isFilled)
                    .controlSize(.small)
                    .disabled(element.shape == .line)
                    .opacity(element.shape == .line ? 0.45 : 1)

                PropertyRow(title: "Füllfarbe") {
                    ColorPicker("", selection: colorBinding(\.fillColor), supportsOpacity: true)
                        .labelsHidden()
                        .controlSize(.small)
                }
                .disabled(!element.isFilled || element.shape == .line)
                .opacity(element.isFilled && element.shape != .line ? 1 : 0.45)
            }

            FormatSection(title: "Position") {
                IntegerPropertyField(title: "X", value: frameBinding(\.xDots))
                IntegerPropertyField(title: "Y", value: frameBinding(\.yDots))
                IntegerPropertyField(title: "Breite", value: frameBinding(\.widthDots, minimum: 1))
                IntegerPropertyField(title: "Höhe", value: frameBinding(\.heightDots, minimum: 1))
                IntegerPropertyField(title: "Drehung", value: rotationBinding)
            }

            FormatSection(title: "Aktionen") {
                Button(role: .destructive, action: delete) {
                    Label("Form löschen", systemImage: "trash")
                }
                .controlSize(.small)
            }
        }
    }

    private func frameBinding(_ keyPath: WritableKeyPath<LabelElementFrame, Int>, minimum: Int = Int.min) -> Binding<Int> {
        Binding(
            get: { element.frame[keyPath: keyPath] },
            set: { newValue in
                var frame = element.frame
                frame[keyPath: keyPath] = max(minimum, newValue)
                element.frame = frame
            }
        )
    }

    private func clampedBinding(_ keyPath: WritableKeyPath<ShapeLabelElement, Int>, _ range: ClosedRange<Int>) -> Binding<Int> {
        Binding(
            get: { element[keyPath: keyPath] },
            set: { element[keyPath: keyPath] = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    private var rotationBinding: Binding<Int> {
        Binding(
            get: { element.rotation.degrees },
            set: { element.rotation = LabelElementRotation(degrees: $0) }
        )
    }

    private func colorBinding(_ keyPath: WritableKeyPath<ShapeLabelElement, LabelElementColor>) -> Binding<Color> {
        Binding(
            get: { Color(labelElementColor: element[keyPath: keyPath]) },
            set: { element[keyPath: keyPath] = LabelElementColor(color: $0) }
        )
    }
}

private extension Color {
    init(labelElementColor color: LabelElementColor) {
        self.init(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: color.alpha
        )
    }
}

private extension LabelElementColor {
    init(color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .black
        red = Double(nsColor.redComponent)
        green = Double(nsColor.greenComponent)
        blue = Double(nsColor.blueComponent)
        alpha = Double(nsColor.alphaComponent)
    }
}
