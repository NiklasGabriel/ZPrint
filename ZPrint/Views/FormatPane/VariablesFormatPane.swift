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
                                    isSelected: selectedVariableID == variable.id,
                                    isRunning: document.printSettings.runningVariableID == variable.id
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

                if let selectedVariable {
                    Button {
                        document.printSettings.runningVariableID = selectedVariable.id
                        document.printSettings = document.printSettings.normalized(for: document.variables)
                    } label: {
                        Label("Als Laufvariable setzen", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .disabled(selectedVariable.type != .sequence)
                    .help("Nur Sequenzvariablen können als Laufvariable drucken.")
                }
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
        document.printSettings = document.printSettings.normalized(for: document.variables)
        selectedVariableID = variable.id
    }

    private var selectedVariable: VariableDefinition? {
        guard let selectedVariableID else {
            return nil
        }

        return document.variables.first { $0.id == selectedVariableID }
    }

}
