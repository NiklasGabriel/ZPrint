//
//  NewDocumentCard.swift
//  ZPrint
//

import SwiftUI

struct NewDocumentCard: View {
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(ZPrintDesign.ColorToken.accent)

                Text("Neues Label")
                    .font(.system(size: 18, weight: .semibold))

                Text("Leere ZPrint-Datei mit Standard-Labelgröße anlegen.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(width: 230, height: 150, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ZPrintDesign.ColorToken.subtlePanelBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
