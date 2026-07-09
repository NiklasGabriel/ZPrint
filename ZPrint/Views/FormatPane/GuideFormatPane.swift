//
//  GuideFormatPane.swift
//  ZPrint
//

import SwiftUI

struct GuideFormatPane: View {
    @Binding var guide: GuideElement
    let labelSize: LabelSize
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatSection(title: "Hilfslinie") {
                PropertyRow(title: "Name") {
                    TextField("Name", text: $guide.name)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }

                PropertyRow(title: "Richtung") {
                    Picker("Richtung", selection: $guide.orientation) {
                        ForEach(GuideOrientation.allCases, id: \.self) { orientation in
                            Text(orientation.displayName)
                                .tag(orientation)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .onChange(of: guide.orientation) { _, _ in
                        guide.positionDots = min(guide.positionDots, maximumPosition)
                    }
                }

                IntegerPropertyField(title: "Position", value: positionBinding)
                    .disabled(guide.locked)

                Toggle("Sichtbar", isOn: $guide.visible)
                    .controlSize(.small)
                Toggle("Gesperrt", isOn: $guide.locked)
                    .controlSize(.small)
            }

            FormatSection(title: "Aktionen") {
                Button(role: .destructive, action: delete) {
                    Label("Hilfslinie löschen", systemImage: "trash")
                }
                .controlSize(.small)
            }
        }
    }

    private var maximumPosition: Int {
        guide.orientation == .vertical ? labelSize.widthDots : labelSize.heightDots
    }

    private var positionBinding: Binding<Int> {
        Binding(
            get: { guide.positionDots },
            set: { guide.positionDots = min(max($0, 0), maximumPosition) }
        )
    }
}
