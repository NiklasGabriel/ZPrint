//
//  GuideElement.swift
//  ZPrint
//

import Foundation

struct GuideElement: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var orientation: GuideOrientation
    var positionDots: Int
    var locked: Bool
    var visible: Bool
    var name: String

    init(
        id: UUID = UUID(),
        orientation: GuideOrientation = .vertical,
        positionDots: Int = 0,
        locked: Bool = false,
        visible: Bool = true,
        name: String = "Hilfslinie"
    ) {
        self.id = id
        self.orientation = orientation
        self.positionDots = positionDots
        self.locked = locked
        self.visible = visible
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case orientation
        case positionDots
        case locked
        case visible
        case name
        case isLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        orientation = try container.decode(GuideOrientation.self, forKey: .orientation)
        positionDots = try container.decodeIfPresent(Int.self, forKey: .positionDots) ?? 0
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked)
            ?? container.decodeIfPresent(Bool.self, forKey: .isLocked)
            ?? false
        visible = try container.decodeIfPresent(Bool.self, forKey: .visible) ?? true
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Hilfslinie"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(orientation, forKey: .orientation)
        try container.encode(positionDots, forKey: .positionDots)
        try container.encode(locked, forKey: .locked)
        try container.encode(visible, forKey: .visible)
        try container.encode(name, forKey: .name)
    }
}

enum GuideOrientation: String, Codable, CaseIterable, Equatable, Sendable {
    case horizontal
    case vertical

    var displayName: String {
        switch self {
        case .horizontal:
            return "Horizontal"
        case .vertical:
            return "Vertikal"
        }
    }
}
