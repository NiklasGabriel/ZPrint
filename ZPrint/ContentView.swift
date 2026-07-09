//
//  ContentView.swift
//  ZPrint
//
//  Created by Niklas Gabriel on 08.07.26.
//

import SwiftUI

struct ContentView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedSection: SidebarSection? = .allBoards

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SidebarSection.allCases, selection: $selectedSection) { section in
                Label {
                    HStack {
                        Text(section.title)
                        Spacer()
                        Text(section.count, format: .number)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: section.systemImage)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(section.color)
                }
                .tag(section)
            }
            .navigationTitle("Boards")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            BoardDetailView(section: selectedSection ?? .allBoards)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            columnVisibility = .all
        }
    }
}

private enum SidebarSection: String, CaseIterable, Identifiable {
    case allBoards
    case recent
    case shared
    case favorites

    var id: Self { self }

    var title: String {
        switch self {
        case .allBoards:
            "Alle Boards"
        case .recent:
            "Zuletzt"
        case .shared:
            "Geteilt"
        case .favorites:
            "Favoriten"
        }
    }

    var systemImage: String {
        switch self {
        case .allBoards:
            "rectangle.stack.fill"
        case .recent:
            "clock.fill"
        case .shared:
            "person.2.fill"
        case .favorites:
            "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .allBoards:
            .cyan
        case .recent:
            .orange
        case .shared:
            .blue
        case .favorites:
            .red
        }
    }

    var count: Int {
        switch self {
        case .allBoards, .recent:
            11
        case .shared, .favorites:
            0
        }
    }

    var emptyStateText: String {
        switch self {
        case .allBoards:
            "Wahle ein Board aus oder erstelle ein neues."
        case .recent:
            "Zuletzt geoffnete Boards erscheinen hier."
        case .shared:
            "Geteilte Boards erscheinen hier."
        case .favorites:
            "Favorisierte Boards erscheinen hier."
        }
    }
}

private struct BoardDetailView: View {
    let section: SidebarSection

    var body: some View {
        ContentUnavailableView {
            Label(section.title, systemImage: section.systemImage)
        } description: {
            Text(section.emptyStateText)
        } actions: {
            Button("Neues Board") {
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle(section.title)
        .toolbar {
            ToolbarItem {
                Button {
                } label: {
                    Label("Neues Board", systemImage: "plus")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
