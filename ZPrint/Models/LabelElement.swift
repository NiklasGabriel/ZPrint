import Foundation

struct TextLabelElement: Codable, Hashable, Identifiable {
    var id: UUID
    var xDots: Int
    var yDots: Int
    var text: String
    var fontHeightDots: Int

    init(id: UUID = UUID(), xDots: Int, yDots: Int, text: String, fontHeightDots: Int = 36) {
        self.id = id
        self.xDots = xDots
        self.yDots = yDots
        self.text = text
        self.fontHeightDots = fontHeightDots
    }
}

struct BarcodeLabelElement: Codable, Hashable, Identifiable {
    var id: UUID
    var xDots: Int
    var yDots: Int
    var value: String
    var heightDots: Int

    init(id: UUID = UUID(), xDots: Int, yDots: Int, value: String, heightDots: Int = 120) {
        self.id = id
        self.xDots = xDots
        self.yDots = yDots
        self.value = value
        self.heightDots = heightDots
    }
}

enum LabelElement: Codable, Hashable, Identifiable {
    case text(TextLabelElement)
    case barcode(BarcodeLabelElement)

    var id: UUID {
        switch self {
        case .text(let element): element.id
        case .barcode(let element): element.id
        }
    }

    var displayName: String {
        switch self {
        case .text: "Text"
        case .barcode: "Barcode"
        }
    }
}
