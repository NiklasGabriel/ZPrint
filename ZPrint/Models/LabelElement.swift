import Foundation

struct TextLabelElement: Codable, Hashable, Identifiable {
    var id: UUID
    var xDots: Int
    var yDots: Int
    var widthDots: Int
    var heightDots: Int
    var text: String
    var fontSizeDots: Int
    var isBold: Bool
    var isItalic: Bool
    var isUnderlined: Bool

    init(
        id: UUID = UUID(),
        xDots: Int = 30,
        yDots: Int = 25,
        widthDots: Int = 520,
        heightDots: Int = 40,
        text: String = "{{name}} | {{number:00000}}",
        fontSizeDots: Int = 28,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false
    ) {
        self.id = id
        self.xDots = xDots
        self.yDots = yDots
        self.widthDots = widthDots
        self.heightDots = heightDots
        self.text = text
        self.fontSizeDots = fontSizeDots
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
    }
}

struct BarcodeLabelElement: Codable, Hashable, Identifiable {
    var id: UUID
    var xDots: Int
    var yDots: Int
    var widthDots: Int
    var heightDots: Int
    var value: String
    var barcodeType: String
    var moduleWidth: Int
    var humanReadable: Bool

    init(
        id: UUID = UUID(),
        xDots: Int = 65,
        yDots: Int = 90,
        widthDots: Int = 470,
        heightDots: Int = 110,
        value: String = "CG-G-{{number:00000}}",
        barcodeType: String = "code128",
        moduleWidth: Int = 2,
        humanReadable: Bool = true
    ) {
        self.id = id
        self.xDots = xDots
        self.yDots = yDots
        self.widthDots = widthDots
        self.heightDots = heightDots
        self.value = value
        self.barcodeType = barcodeType
        self.moduleWidth = moduleWidth
        self.humanReadable = humanReadable
    }
}

enum LabelElement: Codable, Hashable, Identifiable {
    case text(TextLabelElement)
    case barcode(BarcodeLabelElement)

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case xDots
        case yDots
        case widthDots
        case heightDots
        case text
        case fontSizeDots
        case fontHeightDots
        case isBold
        case isItalic
        case isUnderlined
        case value
        case barcodeType
        case moduleWidth
        case humanReadable
    }

    private enum ElementType: String, Codable {
        case text
        case barcode
    }

    var id: UUID {
        switch self {
        case .text(let element): element.id
        case .barcode(let element): element.id
        }
    }

    var xDots: Int {
        switch self {
        case .text(let element): element.xDots
        case .barcode(let element): element.xDots
        }
    }

    var yDots: Int {
        switch self {
        case .text(let element): element.yDots
        case .barcode(let element): element.yDots
        }
    }

    var widthDots: Int {
        switch self {
        case .text(let element): element.widthDots
        case .barcode(let element): element.widthDots
        }
    }

    var heightDots: Int {
        switch self {
        case .text(let element): element.heightDots
        case .barcode(let element): element.heightDots
        }
    }

    var displayName: String {
        switch self {
        case .text: "Text"
        case .barcode: "Barcode"
        }
    }

    mutating func move(toXDots xDots: Int, yDots: Int) {
        switch self {
        case .text(var element):
            element.xDots = xDots
            element.yDots = yDots
            self = .text(element)
        case .barcode(var element):
            element.xDots = xDots
            element.yDots = yDots
            self = .barcode(element)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ElementType.self, forKey: .type)

        switch type {
        case .text:
            let fontSize = try container.decodeIfPresent(Int.self, forKey: .fontSizeDots)
                ?? container.decodeIfPresent(Int.self, forKey: .fontHeightDots)
                ?? 28

            self = .text(TextLabelElement(
                id: try container.decode(UUID.self, forKey: .id),
                xDots: try container.decode(Int.self, forKey: .xDots),
                yDots: try container.decode(Int.self, forKey: .yDots),
                widthDots: try container.decodeIfPresent(Int.self, forKey: .widthDots) ?? 520,
                heightDots: try container.decodeIfPresent(Int.self, forKey: .heightDots) ?? 40,
                text: try container.decode(String.self, forKey: .text),
                fontSizeDots: fontSize,
                isBold: try container.decodeIfPresent(Bool.self, forKey: .isBold) ?? false,
                isItalic: try container.decodeIfPresent(Bool.self, forKey: .isItalic) ?? false,
                isUnderlined: try container.decodeIfPresent(Bool.self, forKey: .isUnderlined) ?? false
            ))

        case .barcode:
            self = .barcode(BarcodeLabelElement(
                id: try container.decode(UUID.self, forKey: .id),
                xDots: try container.decode(Int.self, forKey: .xDots),
                yDots: try container.decode(Int.self, forKey: .yDots),
                widthDots: try container.decodeIfPresent(Int.self, forKey: .widthDots) ?? 470,
                heightDots: try container.decode(Int.self, forKey: .heightDots),
                value: try container.decode(String.self, forKey: .value),
                barcodeType: try container.decodeIfPresent(String.self, forKey: .barcodeType) ?? "code128",
                moduleWidth: try container.decodeIfPresent(Int.self, forKey: .moduleWidth) ?? 2,
                humanReadable: try container.decodeIfPresent(Bool.self, forKey: .humanReadable) ?? true
            ))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let element):
            try container.encode(ElementType.text, forKey: .type)
            try container.encode(element.id, forKey: .id)
            try container.encode(element.xDots, forKey: .xDots)
            try container.encode(element.yDots, forKey: .yDots)
            try container.encode(element.widthDots, forKey: .widthDots)
            try container.encode(element.heightDots, forKey: .heightDots)
            try container.encode(element.text, forKey: .text)
            try container.encode(element.fontSizeDots, forKey: .fontSizeDots)
            try container.encode(element.isBold, forKey: .isBold)
            try container.encode(element.isItalic, forKey: .isItalic)
            try container.encode(element.isUnderlined, forKey: .isUnderlined)

        case .barcode(let element):
            try container.encode(ElementType.barcode, forKey: .type)
            try container.encode(element.id, forKey: .id)
            try container.encode(element.xDots, forKey: .xDots)
            try container.encode(element.yDots, forKey: .yDots)
            try container.encode(element.widthDots, forKey: .widthDots)
            try container.encode(element.heightDots, forKey: .heightDots)
            try container.encode(element.value, forKey: .value)
            try container.encode(element.barcodeType, forKey: .barcodeType)
            try container.encode(element.moduleWidth, forKey: .moduleWidth)
            try container.encode(element.humanReadable, forKey: .humanReadable)
        }
    }
}
