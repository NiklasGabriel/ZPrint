//
//  RecentProjectRow.swift
//  ZPrint
//

import SwiftUI

struct RecentProjectRow: View {
    let project: RecentProject
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                documentIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(project.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(project.exists ? .primary : .secondary)
                        .lineLimit(1)

                    Text(project.folderDisplayName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                if !project.exists {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(rowBackground)
            }
        }
        .buttonStyle(.plain)
        .disabled(!project.exists)
        .onHover { isHovering = $0 }
        .help(project.url.path)
    }

    private var documentIcon: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(project.exists ? ZPrintDesign.ColorToken.accent.opacity(0.14) : Color.secondary.opacity(0.10))
            .frame(width: 38, height: 38)
            .overlay {
                Image(systemName: "tag")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(project.exists ? ZPrintDesign.ColorToken.accent : .secondary)
            }
    }

    private var rowBackground: Color {
        if !project.exists {
            return ZPrintDesign.ColorToken.panelBackground.opacity(0.36)
        }

        return isHovering
            ? ZPrintDesign.ColorToken.selectedFill
            : ZPrintDesign.ColorToken.panelBackground.opacity(0.62)
    }
}
