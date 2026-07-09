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
    var fontFamilyName: String
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
        fontFamilyName: String = TextLabelFontCatalog.systemFamilyName,
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
        self.fontFamilyName = fontFamilyName
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
        case fontFamilyName
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
        let fallback = TextLabelElement()

        id = container.decodeOrDefault(UUID.self, forKey: .id, default: fallback.id)
        name = container.decodeOrDefault(String.self, forKey: .name, default: fallback.name)
        frame = container.decodeOrDefault(LabelElementFrame.self, forKey: .frame, default: fallback.frame)
        text = container.decodeOrDefault(String.self, forKey: .text, default: fallback.text)
        fontFamilyName = (try? container.decodeIfPresent(String.self, forKey: .fontFamilyName))
            ?? TextLabelFontCatalog.systemFamilyName
        fontSizeDots = max(1, container.decodeOrDefault(Int.self, forKey: .fontSizeDots, default: fallback.fontSizeDots))
        isBold = container.decodeOrDefault(Bool.self, forKey: .isBold, default: fallback.isBold)
        isItalic = container.decodeOrDefault(Bool.self, forKey: .isItalic, default: fallback.isItalic)
        isUnderlined = container.decodeOrDefault(Bool.self, forKey: .isUnderlined, default: fallback.isUnderlined)
        alignment = container.decodeOrDefault(TextElementAlignment.self, forKey: .alignment, default: fallback.alignment)
        rotation = container.decodeOrDefault(LabelElementRotation.self, forKey: .rotation, default: fallback.rotation)
        variableKey = try? container.decodeIfPresent(String.self, forKey: .variableKey)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(frame, forKey: .frame)
        try container.encode(text, forKey: .text)
        try container.encode(fontFamilyName, forKey: .fontFamilyName)
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
