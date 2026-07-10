//
//  RecentProjectsStore.swift
//  ZPrint
//

import AppKit
import Combine
import Foundation

@MainActor
final class RecentProjectsStore: ObservableObject {
    static let shared = RecentProjectsStore()

    @Published private(set) var projects: [RecentProject] = []

    private let userDefaultsKey = "org.niklasgabriel.zprint.recentProjects"
    private let maximumProjectCount = 10
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func reload() {
        var mergedProjects = storedProjects()

        for url in NSDocumentController.shared.recentDocumentURLs where url.pathExtension.lowercased() == "zprint" {
            if let existingIndex = mergedProjects.firstIndex(where: { $0.url == url }) {
                var existingProject = mergedProjects.remove(at: existingIndex)
                existingProject.lastOpened = Date()
                mergedProjects.insert(existingProject, at: 0)
            } else {
                mergedProjects.insert(RecentProject(url: url, lastOpened: Date()), at: 0)
            }
        }

        projects = Array(mergedProjects.filter(\.exists).prefix(maximumProjectCount))
        persist(projects)
    }

    func record(_ url: URL) {
        guard url.pathExtension.lowercased() == "zprint" else {
            return
        }

        NSDocumentController.shared.noteNewRecentDocumentURL(url)

        projects.removeAll { $0.url == url }
        projects.insert(
            RecentProject(
                url: url,
                lastOpened: Date(),
                bookmarkData: Self.securityScopedBookmarkData(for: url)
            ),
            at: 0
        )
        projects = Array(projects.filter(\.exists).prefix(maximumProjectCount))
        persist(projects)
    }

    func removeMissingProjects() {
        projects = projects.filter(\.exists)
        persist(projects)
    }

    private func storedProjects() -> [RecentProject] {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let projects = try? JSONDecoder().decode([RecentProject].self, from: data) else {
            return []
        }

        return projects
    }

    private func persist(_ projects: [RecentProject]) {
        guard let data = try? JSONEncoder().encode(projects) else {
            return
        }

        userDefaults.set(data, forKey: userDefaultsKey)
    }

    private static func securityScopedBookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}

struct RecentProject: Codable, Equatable, Identifiable, Sendable {
    var url: URL
    var lastOpened: Date
    var bookmarkData: Data? = nil

    var id: String { url.path }
    var displayName: String { url.deletingPathExtension().lastPathComponent }
    var folderDisplayName: String {
        let folderURL = url.deletingLastPathComponent()
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path

        if folderURL.path.hasPrefix(homeDirectory) {
            return "~" + folderURL.path.dropFirst(homeDirectory.count)
        }

        return folderURL.path
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    var hasSecurityScopedBookmark: Bool {
        bookmarkData != nil
    }

    func resolvedURL() -> URL {
        guard let bookmarkData else {
            return url
        }

        var isStale = false
        return (try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )) ?? url
    }

    func startAccessingSecurityScopedResource() -> (url: URL, didStartAccessing: Bool) {
        let resolvedURL = resolvedURL()
        return (resolvedURL, resolvedURL.startAccessingSecurityScopedResource())
    }
}
