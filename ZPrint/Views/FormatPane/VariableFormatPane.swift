//
//  VariableFormatPane.swift
//  ZPrint
//

import SwiftUI

struct VariableFormatPane: View {
    @Binding var variable: VariableDefinition
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatSection(title: "Variable bearbeiten") {
                PropertyRow(title: "Name") {
                    TextField("Name", text: normalizedNameBinding)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }

                PropertyRow(title: "Typ") {
                    Picker("Typ", selection: $variable.type) {
                        ForEach(VariableType.allCases, id: \.self) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                PropertyRow(title: "Default") {
                    TextField("Default", text: $variable.defaultValue)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }

                PropertyRow(title: "Format") {
                    TextField("Format", text: $variable.format)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }
                .disabled(variable.type != .sequence)
                .opacity(variable.type == .sequence ? 1 : 0.45)
            }

            FormatSection(title: "Sequenz") {
                IntegerPropertyField(title: "Start", value: clampedBinding(\.startValue, minimum: 1))
                IntegerPropertyField(title: "Ende", value: clampedBinding(\.endValue, minimum: 1))
                IntegerPropertyField(title: "Schritt", value: clampedBinding(\.step, minimum: 1))
            }
            .disabled(variable.type != .sequence)
            .opacity(variable.type == .sequence ? 1 : 0.45)

            FormatSection(title: "Platzhalter") {
                Text(variable.placeholder)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            FormatSection(title: "Aktionen") {
                Button(role: .destructive, action: delete) {
                    Label("Variable löschen", systemImage: "trash")
                }
                .controlSize(.small)
            }
        }
    }

    private var normalizedNameBinding: Binding<String> {
        Binding(
            get: { variable.name },
            set: { newValue in
                variable.name = newValue
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: " ", with: "_")
            }
        )
    }

    private func clampedBinding(
        _ keyPath: WritableKeyPath<VariableDefinition, Int>,
        minimum: Int
    ) -> Binding<Int> {
        Binding(
            get: { variable[keyPath: keyPath] },
            set: { variable[keyPath: keyPath] = max(minimum, $0) }
        )
    }
}
