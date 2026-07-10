//
//  StartScreenView.swift
//  ZPrint
//

import SwiftUI

struct StartScreenView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @StateObject private var recentProjectsStore = RecentProjectsStore.shared
    @State private var statusMessage: String?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: 42)

                appIdentity

                Spacer()
                    .frame(height: 76)

                VStack(spacing: 14) {
                    StartActionButton(
                        title: "Neues Label erstellen ...",
                        systemImage: "plus.square"
                    ) {
                        DocumentLauncher.shared.createNewDocument { didCreate in
                            if didCreate {
                                dismissWindow(id: ZPrintApp.startWindowID)
                            }
                        }
                    }

                    StartActionButton(
                        title: "Bestehendes Projekt öffnen ...",
                        systemImage: "folder"
                    ) {
                        DocumentLauncher.shared.openDocument { didOpen in
                            recentProjectsStore.reload()
                            if didOpen {
                                dismissWindow(id: ZPrintApp.startWindowID)
                            }
                        }
                    }

                    StartActionButton(
                        title: "Vorlage auswählen ...",
                        systemImage: "rectangle.grid.2x2",
                        isDisabled: true
                    ) {}
                }
                .frame(width: 440)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                }

                Spacer(minLength: 42)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ZPrintDesign.ColorToken.panelBackground)

            RecentProjectsView(
                projects: recentProjectsStore.projects,
                openProject: openRecentProject,
                reloadProjects: {
                    recentProjectsStore.reload()
                }
            )
            .frame(width: 380)
        }
        .frame(width: 980, height: 620)
        .frame(minWidth: 900, minHeight: 560)
        .background(ZPrintDesign.ColorToken.appBackground)
        .onAppear {
            recentProjectsStore.reload()
        }
    }

    private var appIdentity: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 138, height: 138)
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 7)

            VStack(spacing: 3) {
                Text("ZPrint")
                    .font(.system(size: 42, weight: .bold))

                Text("Label Designer")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func openRecentProject(_ project: RecentProject) {
        guard project.exists else {
            statusMessage = "Die Datei ist nicht mehr vorhanden."
            recentProjectsStore.removeMissingProjects()
            return
        }

        DocumentLauncher.shared.openRecentProject(project) { didOpen in
            recentProjectsStore.reload()
            if didOpen {
                dismissWindow(id: ZPrintApp.startWindowID)
            }
        }
    }
}
