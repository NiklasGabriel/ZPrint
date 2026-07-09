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
        let fallback = ShapeLabelElement()

        id = container.decodeOrDefault(UUID.self, forKey: .id, default: fallback.id)
        name = container.decodeOrDefault(String.self, forKey: .name, default: fallback.name)
        frame = container.decodeOrDefault(LabelElementFrame.self, forKey: .frame, default: fallback.frame)
        shape = container.decodeOrDefault(LabelShapeKind.self, forKey: .shape, default: fallback.shape)
        strokeWidthDots = max(1, container.decodeOrDefault(Int.self, forKey: .strokeWidthDots, default: fallback.strokeWidthDots))
        isFilled = container.decodeOrDefault(Bool.self, forKey: .isFilled, default: fallback.isFilled)
        hasStroke = container.decodeOrDefault(Bool.self, forKey: .hasStroke, default: fallback.hasStroke)
        strokeColor = container.decodeOrDefault(LabelElementColor.self, forKey: .strokeColor, default: fallback.strokeColor)
        fillColor = container.decodeOrDefault(LabelElementColor.self, forKey: .fillColor, default: fallback.fillColor)
        rotation = container.decodeOrDefault(LabelElementRotation.self, forKey: .rotation, default: fallback.rotation)
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

    init(
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    private enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
        case alpha
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        red = Self.clampedChannel(container.decodeOrDefault(Double.self, forKey: .red, default: 0))
        green = Self.clampedChannel(container.decodeOrDefault(Double.self, forKey: .green, default: 0))
        blue = Self.clampedChannel(container.decodeOrDefault(Double.self, forKey: .blue, default: 0))
        alpha = Self.clampedChannel(container.decodeOrDefault(Double.self, forKey: .alpha, default: 1))
    }

    private static func clampedChannel(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
