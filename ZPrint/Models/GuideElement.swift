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
        let fallback = GuideElement()

        id = container.decodeOrDefault(UUID.self, forKey: .id, default: fallback.id)
        orientation = container.decodeOrDefault(GuideOrientation.self, forKey: .orientation, default: fallback.orientation)
        positionDots = max(0, container.decodeOrDefault(Int.self, forKey: .positionDots, default: fallback.positionDots))
        locked = (try? container.decodeIfPresent(Bool.self, forKey: .locked))
            ?? (try? container.decodeIfPresent(Bool.self, forKey: .isLocked))
            ?? fallback.locked
        visible = container.decodeOrDefault(Bool.self, forKey: .visible, default: fallback.visible)
        name = container.decodeOrDefault(String.self, forKey: .name, default: fallback.name)
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

    func clamped(to labelSize: LabelSize) -> GuideElement {
        var guide = self
        let maxPosition = guide.orientation == .vertical
            ? labelSize.widthDots
            : labelSize.heightDots
        guide.positionDots = min(max(guide.positionDots, 0), maxPosition)
        return guide
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
