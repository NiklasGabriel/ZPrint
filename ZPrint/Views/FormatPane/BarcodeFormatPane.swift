//
//  BarcodeFormatPane.swift
//  ZPrint
//

import SwiftUI

struct BarcodeFormatPane: View {
    @Binding var element: BarcodeLabelElement
    let labelSize: LabelSize
    let variables: [VariableDefinition]
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatSection(title: "Barcode formatieren") {
                PropertyRow(title: "Wert") {
                    TextField("Wert", text: $element.value)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }

                VariableInsertControl(variables: variables) { variable in
                    element.value.append(variable.placeholder)
                }

                PropertyRow(title: "Typ") {
                    Picker("Typ", selection: $element.symbology) {
                        Text(BarcodeSymbology.code128.displayName)
                            .tag(BarcodeSymbology.code128)
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                IntegerPropertyField(title: "Modulbreite", value: clampedBinding(\.moduleWidth, 1...12))
                Toggle("Klarschrift anzeigen", isOn: $element.showsHumanReadableText)
                    .controlSize(.small)
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
                    Label("Barcode löschen", systemImage: "trash")
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

    private func clampedBinding(_ keyPath: WritableKeyPath<BarcodeLabelElement, Int>, _ range: ClosedRange<Int>) -> Binding<Int> {
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
}
