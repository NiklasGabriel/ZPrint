//
//  StartScreenView.swift
//  ZPrint
//

import SwiftUI

struct StartScreenView: View {
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ZPrint")
                        .font(.system(size: 34, weight: .bold))
                    Text("Labelvorlagen erstellen und verwalten")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                NewDocumentCard()

                TemplateGalleryView()

                Spacer()
            }
            .padding(44)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ZPrintDesign.ColorToken.panelBackground)

            RecentProjectsView()
                .frame(width: 360)
        }
        .frame(minWidth: 960, minHeight: 620)
        .background(ZPrintDesign.ColorToken.appBackground)
    }
}
