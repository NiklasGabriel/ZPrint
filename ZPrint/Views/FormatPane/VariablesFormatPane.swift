//
//  VariablesFormatPane.swift
//  ZPrint
//

import SwiftUI

struct VariablesFormatPane: View {
    @Binding var document: ZPrintDocument
    @Binding var selectedVariableID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatSection(title: "Variablen") {
                if document.variables.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Keine Variablen", systemImage: "curlybraces")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("Variablen können später in Text- und Barcodewerte eingefügt werden.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 94), spacing: 6)],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(document.variables) { variable in
                            Button {
                                selectedVariableID = variable.id
                            } label: {
                                VariableChipView(
                                    variable: variable,
                                    isSelected: selectedVariableID == variable.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            FormatSection(title: "Aktionen") {
                Button(action: addVariable) {
                    Label("Variable anlegen", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }

            FormatSection(title: "Hinweis") {
                Text("Wähle eine Variable aus, um Name, Typ, Format, Präfix und Schritt rechts zu bearbeiten.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func addVariable() {
        let baseName = "variable"
        var name = baseName
        var suffix = 2

        while document.variables.contains(where: { $0.name == name }) {
            name = "\(baseName)\(suffix)"
            suffix += 1
        }

        let variable = VariableDefinition(name: name)
        document.variables.append(variable)
        selectedVariableID = variable.id
    }

}
