//
//  TextLabelElement.swift
//  ZPrint
//

import Foundation

struct TextLabelElement: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var frame: LabelElementFrame
    var text: String
    var fontSizeDots: Int
    var isBold: Bool
    var isItalic: Bool
    var isUnderlined: Bool
    var alignment: TextElementAlignment
    var rotation: LabelElementRotation
    var variableKey: String?

    init(
        id: UUID = UUID(),
        name: String = "Text",
        frame: LabelElementFrame = .zero,
        text: String = "",
        fontSizeDots: Int = 32,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        alignment: TextElementAlignment = .left,
        rotation: LabelElementRotation = .degrees0,
        variableKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.text = text
        self.fontSizeDots = fontSizeDots
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.alignment = alignment
        self.rotation = rotation
        self.variableKey = variableKey
    }

    static func standardNewElement() -> TextLabelElement {
        TextLabelElement(
            name: "Text",
            frame: LabelElementFrame(
                xDots: 30,
                yDots: 25,
                widthDots: 520,
                heightDots: 40
            ),
            text: "Text",
            fontSizeDots: 28
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case frame
        case text
        case fontSizeDots
        case isBold
        case isItalic
        case isUnderlined
        case alignment
        case rotation
        case variableKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        frame = try container.decode(LabelElementFrame.self, forKey: .frame)
        text = try container.decode(String.self, forKey: .text)
        fontSizeDots = try container.decode(Int.self, forKey: .fontSizeDots)
        isBold = try container.decodeIfPresent(Bool.self, forKey: .isBold) ?? false
        isItalic = try container.decodeIfPresent(Bool.self, forKey: .isItalic) ?? false
        isUnderlined = try container.decodeIfPresent(Bool.self, forKey: .isUnderlined) ?? false
        alignment = try container.decodeIfPresent(TextElementAlignment.self, forKey: .alignment) ?? .left
        rotation = try container.decode(LabelElementRotation.self, forKey: .rotation)
        variableKey = try container.decodeIfPresent(String.self, forKey: .variableKey)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(frame, forKey: .frame)
        try container.encode(text, forKey: .text)
        try container.encode(fontSizeDots, forKey: .fontSizeDots)
        try container.encode(isBold, forKey: .isBold)
        try container.encode(isItalic, forKey: .isItalic)
        try container.encode(isUnderlined, forKey: .isUnderlined)
        try container.encode(alignment, forKey: .alignment)
        try container.encode(rotation, forKey: .rotation)
        try container.encodeIfPresent(variableKey, forKey: .variableKey)
    }
}

enum TextElementAlignment: String, Codable, CaseIterable, Equatable, Sendable {
    case left
    case center
    case right

    var displayName: String {
        switch self {
        case .left:
            return "Links"
        case .center:
            return "Mitte"
        case .right:
            return "Rechts"
        }
    }
}
