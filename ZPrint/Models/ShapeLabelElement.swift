//
//  ShapeLabelElement.swift
//  ZPrint
//

import Foundation

struct ShapeLabelElement: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var frame: LabelElementFrame
    var shape: LabelShapeKind
    var strokeWidthDots: Int
    var isFilled: Bool
    var hasStroke: Bool
    var strokeColor: LabelElementColor
    var fillColor: LabelElementColor
    var rotation: LabelElementRotation

    init(
        id: UUID = UUID(),
        name: String = "Shape",
        frame: LabelElementFrame = .zero,
        shape: LabelShapeKind = .rectangle,
        strokeWidthDots: Int = 2,
        isFilled: Bool = false,
        hasStroke: Bool = true,
        strokeColor: LabelElementColor = .black,
        fillColor: LabelElementColor = .lightGray,
        rotation: LabelElementRotation = .degrees0
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.shape = shape
        self.strokeWidthDots = strokeWidthDots
        self.isFilled = isFilled
        self.hasStroke = hasStroke
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.rotation = rotation
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case frame
        case shape
        case strokeWidthDots
        case isFilled
        case hasStroke
        case strokeColor
        case fillColor
        case rotation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        frame = try container.decode(LabelElementFrame.self, forKey: .frame)
        shape = try container.decode(LabelShapeKind.self, forKey: .shape)
        strokeWidthDots = try container.decode(Int.self, forKey: .strokeWidthDots)
        isFilled = try container.decode(Bool.self, forKey: .isFilled)
        hasStroke = try container.decodeIfPresent(Bool.self, forKey: .hasStroke) ?? true
        strokeColor = try container.decodeIfPresent(LabelElementColor.self, forKey: .strokeColor) ?? .black
        fillColor = try container.decodeIfPresent(LabelElementColor.self, forKey: .fillColor) ?? .lightGray
        rotation = try container.decodeIfPresent(LabelElementRotation.self, forKey: .rotation) ?? .degrees0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(frame, forKey: .frame)
        try container.encode(shape, forKey: .shape)
        try container.encode(strokeWidthDots, forKey: .strokeWidthDots)
        try container.encode(isFilled, forKey: .isFilled)
        try container.encode(hasStroke, forKey: .hasStroke)
        try container.encode(strokeColor, forKey: .strokeColor)
        try container.encode(fillColor, forKey: .fillColor)
        try container.encode(rotation, forKey: .rotation)
    }
}

enum LabelShapeKind: String, Codable, CaseIterable, Equatable, Sendable {
    case rectangle
    case roundedRectangle
    case ellipse
    case capsule
    case triangle
    case line

    var displayName: String {
        switch self {
        case .rectangle:
            return "Rechteck"
        case .roundedRectangle:
            return "Abgerundet"
        case .ellipse:
            return "Ellipse"
        case .capsule:
            return "Kapsel"
        case .triangle:
            return "Dreieck"
        case .line:
            return "Linie"
        }
    }
}

struct LabelElementColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let black = LabelElementColor(red: 0, green: 0, blue: 0, alpha: 0.86)
    static let lightGray = LabelElementColor(red: 0, green: 0, blue: 0, alpha: 0.10)
}
