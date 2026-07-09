//
//  ModeSwitcher.swift
//  ZPrint
//

import SwiftUI

struct ModeSwitcher: View {
    @Binding var mode: DocumentViewMode

    var body: some View {
        Picker("Modus", selection: $mode) {
            ForEach([DocumentViewMode.edit, .preview, .print], id: \.self) { mode in
                Label(mode.displayName, systemImage: mode.systemImageName)
                    .labelStyle(.titleAndIcon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.mini)
        .labelsHidden()
    }
}
