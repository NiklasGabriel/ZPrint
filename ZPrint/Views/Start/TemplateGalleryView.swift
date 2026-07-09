//
//  TemplateGalleryView.swift
//  ZPrint
//

import SwiftUI

struct TemplateGalleryView: View {
    private let templates = [
        "51 x 25 mm",
        "DHL 4 x 6 Zoll",
        "Produktetikett"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vorlagen")
                .font(.system(size: 15, weight: .semibold))

            HStack(spacing: 12) {
                ForEach(templates, id: \.self) { template in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white)
                            .frame(height: 72)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
                            }

                        Text(template)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(10)
                    .frame(width: 136)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(ZPrintDesign.ColorToken.subtlePanelBackground)
                    }
                }
            }
        }
    }
}
