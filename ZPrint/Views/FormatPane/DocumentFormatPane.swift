//
//  DocumentFormatPane.swift
//  ZPrint
//

import SwiftUI

struct DocumentFormatPane: View {
    @Binding var document: ZPrintDocument
    @Binding var documentTitle: String
    let isFileBackedDocument: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatSection(title: "Dokument") {
                PropertyRow(title: "Dateiname") {
                    TextField("Dateiname", text: $documentTitle)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }

                PropertyValueRow(title: "Datei", value: ".zprint")
                PropertyValueRow(title: "Status", value: isFileBackedDocument ? "Gespeichert" : "Noch ungespeichert")
                PropertyValueRow(title: "Version", value: "\(document.fileVersion)")
            }

            FormatSection(title: "Label") {
                PropertyRow(title: "Größe") {
                    Picker("Größe", selection: labelSizeSelection) {
                        ForEach(LabelSize.standardSizes) { labelSize in
                            Text(labelSize.name)
                                .tag(labelSize.id)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                PropertyValueRow(title: "DPI", value: "\(document.label.dotsPerInch)")
                PropertyValueRow(title: "mm", value: "\(formatMillimeters(document.label.widthMillimeters)) x \(formatMillimeters(document.label.heightMillimeters))")
                PropertyValueRow(title: "Dots", value: "\(document.label.widthDots) x \(document.label.heightDots)")
                PropertyValueRow(title: "Elemente", value: "\(document.elements.count)")
            }

            FormatSection(title: "Hinweise") {
                Text(isFileBackedDocument ? "Der Dokumentname folgt dem Dateinamen. Änderungen an diesem Feld benennen die .zprint-Datei um." : "Nach dem ersten Speichern übernimmt der Dokumentname automatisch den Dateinamen.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var labelSizeSelection: Binding<String> {
        Binding(
            get: { document.labelSizeId },
            set: { newID in
                guard let labelSize = LabelSize.standardSizes.first(where: { $0.id == newID }) else {
                    return
                }

                document.labelSizeId = labelSize.id
                document.label = labelSize
                document.elements = document.elements.map { element in
                    element.replacingFrame(element.frame.clamped(to: labelSize))
                }
                document.guides = document.guides.map { guide in
                    guide.clamped(to: labelSize)
                }
            }
        )
    }

    private func formatMillimeters(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
