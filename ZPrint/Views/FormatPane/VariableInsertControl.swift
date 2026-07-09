//
//  VariableInsertControl.swift
//  ZPrint
//

import SwiftUI

struct VariableInsertControl: View {
    let variables: [VariableDefinition]
    let insert: (VariableDefinition) -> Void

    var body: some View {
        Menu {
            if variables.isEmpty {
                Text("Keine Variablen")
            } else {
                ForEach(variables) { variable in
                    Button(variable.chipTitle) {
                        insert(variable)
                    }
                }
            }
        } label: {
            Label("Variable einfügen", systemImage: "curlybraces")
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .menuStyle(.button)
        .controlSize(.small)
    }
}
