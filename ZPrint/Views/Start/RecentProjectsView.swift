//
//  RecentProjectsView.swift
//  ZPrint
//

import SwiftUI

struct RecentProjectsView: View {
    let projects: [RecentProject]
    let openProject: (RecentProject) -> Void
    let reloadProjects: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Zuletzt verwendet")
                    .font(.system(size: 17, weight: .semibold))

                Spacer()

                Button {
                    reloadProjects()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Liste aktualisieren")
            }

            if projects.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(projects) { project in
                            RecentProjectRow(project: project) {
                                openProject(project)
                            }
                        }
                    }
                    .padding(.trailing, 2)
                }
                .scrollIndicators(.never)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(ZPrintDesign.ColorToken.subtlePanelBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ZPrintDesign.ColorToken.softBorder)
                .frame(width: 1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(ZPrintDesign.ColorToken.secondaryText)

            Text("Noch keine zuletzt verwendeten Projekte.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ZPrintDesign.ColorToken.panelBackground.opacity(0.52))
        }
    }
}
