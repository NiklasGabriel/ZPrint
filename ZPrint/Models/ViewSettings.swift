//
//  ViewSettings.swift
//  ZPrint
//

import Foundation

struct ViewSettings: Codable, Equatable, Sendable {
    var mode: DocumentViewMode
    var isSidebarVisible: Bool
    var zoomScale: Double

    static let standard = ViewSettings(
        mode: .edit,
        isSidebarVisible: true,
        zoomScale: 1.0
    )

    private enum CodingKeys: String, CodingKey {
        case mode
        case isSidebarVisible
        case zoomScale
    }

    init(
        mode: DocumentViewMode,
        isSidebarVisible: Bool,
        zoomScale: Double
    ) {
        self.mode = mode
        self.isSidebarVisible = isSidebarVisible
        self.zoomScale = min(max(zoomScale, 0.25), 3.0)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        mode = container.decodeOrDefault(DocumentViewMode.self, forKey: .mode, default: Self.standard.mode)
        isSidebarVisible = container.decodeOrDefault(Bool.self, forKey: .isSidebarVisible, default: Self.standard.isSidebarVisible)
        zoomScale = min(max(container.decodeOrDefault(Double.self, forKey: .zoomScale, default: Self.standard.zoomScale), 0.25), 3.0)
    }
}

enum DocumentViewMode: String, Codable, Equatable, Sendable {
    case edit
    case preview
    case print

    var displayName: String {
        switch self {
        case .edit:
            return "Bearbeiten"
        case .preview:
            return "Vorschau"
        case .print:
            return "Drucken"
        }
    }

    var systemImageName: String {
        switch self {
        case .edit:
            return "pencil"
        case .preview:
            return "eye"
        case .print:
            return "printer"
        }
    }
}
