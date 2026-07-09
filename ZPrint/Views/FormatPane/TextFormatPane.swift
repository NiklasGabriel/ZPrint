//
//  TextFormatPane.swift
//  ZPrint
//

import SwiftUI

struct TextFormatPane: View {
    @Binding var element: TextLabelElement
    let labelSize: LabelSize
    let variables: [VariableDefinition]
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatSection(title: "Text formatieren") {
                TextEditor(text: $element.text)
                    .font(TextLabelFontCatalog.swiftUIFont(
                        familyName: element.fontFamilyName,
                        size: 12,
                        isBold: element.isBold
                    ))
                    .frame(minHeight: 76)
                    .padding(4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
                    }

                VariableInsertControl(variables: variables) { variable in
                    element.text.append(variable.placeholder)
                }
            }

            FormatSection(title: "Typografie") {
                PropertyRow(title: "Schrift") {
                    Picker("Schrift", selection: $element.fontFamilyName) {
                        ForEach(TextLabelFontCatalog.fontFamilyNames, id: \.self) { familyName in
                            Text(TextLabelFontCatalog.displayName(for: familyName))
                                .tag(familyName)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 174)
                }

                IntegerPropertyField(title: "Größe", value: clampedBinding(\.fontSizeDots, 6...200))

                PropertyRow(title: "Stil") {
                    HStack(spacing: 5) {
                        Toggle("B", isOn: $element.isBold)
                            .toggleStyle(.button)
                            .fontWeight(.bold)
                            .help("Fett")
                        Toggle("I", isOn: $element.isItalic)
                            .toggleStyle(.button)
                            .italic()
                            .help("Kursiv")
                        Toggle("U", isOn: $element.isUnderlined)
                            .toggleStyle(.button)
                            .underline()
                            .help("Unterstrichen")
                    }
                    .controlSize(.small)
                }

                PropertyRow(title: "Ausrichtung") {
                    Picker("Ausrichtung", selection: $element.alignment) {
                        Image(systemName: "text.alignleft").tag(TextElementAlignment.left)
                        Image(systemName: "text.aligncenter").tag(TextElementAlignment.center)
                        Image(systemName: "text.alignright").tag(TextElementAlignment.right)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 116)
                }
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
                    Label("Text löschen", systemImage: "trash")
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

    private func clampedBinding(_ keyPath: WritableKeyPath<TextLabelElement, Int>, _ range: ClosedRange<Int>) -> Binding<Int> {
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
