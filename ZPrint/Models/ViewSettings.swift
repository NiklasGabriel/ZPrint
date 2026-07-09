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
