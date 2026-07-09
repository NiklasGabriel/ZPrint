//
//  LabelElement.swift
//  ZPrint
//

import Foundation

enum LabelElement: Codable, Equatable, Identifiable, Sendable {
    case text(TextLabelElement)
    case barcode(BarcodeLabelElement)
    case shape(ShapeLabelElement)

    var id: UUID {
        switch self {
        case .text(let element):
            return element.id
        case .barcode(let element):
            return element.id
        case .shape(let element):
            return element.id
        }
    }

    var frame: LabelElementFrame {
        switch self {
        case .text(let element):
            return element.frame
        case .barcode(let element):
            return element.frame
        case .shape(let element):
            return element.frame
        }
    }

    func replacingFrame(_ frame: LabelElementFrame) -> LabelElement {
        switch self {
        case .text(var element):
            element.frame = frame
            return .text(element)
        case .barcode(var element):
            element.frame = frame
            return .barcode(element)
        case .shape(var element):
            element.frame = frame
            return .shape(element)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum ElementType: String, Codable {
        case text
        case barcode
        case shape
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ElementType.self, forKey: .type)

        switch type {
        case .text:
            self = .text(try container.decode(TextLabelElement.self, forKey: .payload))
        case .barcode:
            self = .barcode(try container.decode(BarcodeLabelElement.self, forKey: .payload))
        case .shape:
            self = .shape(try container.decode(ShapeLabelElement.self, forKey: .payload))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let element):
            try container.encode(ElementType.text, forKey: .type)
            try container.encode(element, forKey: .payload)
        case .barcode(let element):
            try container.encode(ElementType.barcode, forKey: .type)
            try container.encode(element, forKey: .payload)
        case .shape(let element):
            try container.encode(ElementType.shape, forKey: .type)
            try container.encode(element, forKey: .payload)
        }
    }
}

struct LabelElementFrame: Codable, Equatable, Sendable {
    var xDots: Int
    var yDots: Int
    var widthDots: Int
    var heightDots: Int

    static let zero = LabelElementFrame(
        xDots: 0,
        yDots: 0,
        widthDots: 0,
        heightDots: 0
    )

    func clamped(to labelSize: LabelSize) -> LabelElementFrame {
        let maxX = max(0, labelSize.widthDots - widthDots)
        let maxY = max(0, labelSize.heightDots - heightDots)

        return LabelElementFrame(
            xDots: min(max(xDots, 0), maxX),
            yDots: min(max(yDots, 0), maxY),
            widthDots: widthDots,
            heightDots: heightDots
        )
    }
}

enum LabelElementRotation: Int, Codable, Equatable, Sendable {
    case degrees0 = 0
    case degrees90 = 90
    case degrees180 = 180
    case degrees270 = 270
}
