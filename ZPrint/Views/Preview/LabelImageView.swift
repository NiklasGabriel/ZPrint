//
//  LabelImageView.swift
//  ZPrint
//

import SwiftUI

struct LabelImageView: View {
    let imageData: Data

    var body: some View {
        Group {
            if let image = LabelImageImporter.image(from: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipped()
    }
}
