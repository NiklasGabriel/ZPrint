//
//  BarcodeLabelElement.swift
//  ZPrint
//

import Foundation

struct BarcodeLabelElement: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var frame: LabelElementFrame
    var symbology: BarcodeSymbology
    var value: String
    var moduleWidth: Int
    var showsHumanReadableText: Bool
    var rotation: LabelElementRotation
    var variableKey: String?

    init(
        id: UUID = UUID(),
        name: String = "Barcode",
        frame: LabelElementFrame = .zero,
        symbology: BarcodeSymbology = .code128,
        value: String = "",
        moduleWidth: Int = 2,
        showsHumanReadableText: Bool = false,
        rotation: LabelElementRotation = .degrees0,
        variableKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.symbology = symbology
        self.value = value
        self.moduleWidth = moduleWidth
        self.showsHumanReadableText = showsHumanReadableText
        self.rotation = rotation
        self.variableKey = variableKey
    }

    static func standardNewElement() -> BarcodeLabelElement {
        BarcodeLabelElement(
            name: "Barcode",
            frame: LabelElementFrame(
                xDots: 65,
                yDots: 90,
                widthDots: 470,
                heightDots: 110
            ),
            symbology: .code128,
            value: "",
            moduleWidth: 2,
            showsHumanReadableText: false
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case frame
        case symbology
        case value
        case moduleWidth
        case showsHumanReadableText
        case rotation
        case variableKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = BarcodeLabelElement()

        id = container.decodeOrDefault(UUID.self, forKey: .id, default: fallback.id)
        name = container.decodeOrDefault(String.self, forKey: .name, default: fallback.name)
        frame = container.decodeOrDefault(LabelElementFrame.self, forKey: .frame, default: fallback.frame)
        symbology = container.decodeOrDefault(BarcodeSymbology.self, forKey: .symbology, default: fallback.symbology)
        value = container.decodeOrDefault(String.self, forKey: .value, default: fallback.value)
        moduleWidth = max(1, container.decodeOrDefault(Int.self, forKey: .moduleWidth, default: fallback.moduleWidth))
        showsHumanReadableText = container.decodeOrDefault(Bool.self, forKey: .showsHumanReadableText, default: fallback.showsHumanReadableText)
        rotation = container.decodeOrDefault(LabelElementRotation.self, forKey: .rotation, default: fallback.rotation)
        variableKey = try? container.decodeIfPresent(String.self, forKey: .variableKey)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(frame, forKey: .frame)
        try container.encode(symbology, forKey: .symbology)
        try container.encode(value, forKey: .value)
        try container.encode(moduleWidth, forKey: .moduleWidth)
        try container.encode(showsHumanReadableText, forKey: .showsHumanReadableText)
        try container.encode(rotation, forKey: .rotation)
        try container.encodeIfPresent(variableKey, forKey: .variableKey)
    }
}

enum BarcodeSymbology: String, Codable, Equatable, Sendable {
    case code128
    case ean13
    case qrCode

    var displayName: String {
        switch self {
        case .code128:
            return "Code 128"
        case .ean13:
            return "EAN-13"
        case .qrCode:
            return "QR Code"
        }
    }
}
