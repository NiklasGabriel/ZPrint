//
//  LabelSize.swift
//  ZPrint
//

import Foundation

struct LabelSize: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var widthMillimeters: Double
    var heightMillimeters: Double
    var dotsPerInch: Int
    var widthDots: Int
    var heightDots: Int
    var isFavorite: Bool
    var isInStock: Bool

    var displayName: String {
        "\(name) (\(widthDots) x \(heightDots) dots)"
    }

    init(
        id: String,
        name: String,
        widthMillimeters: Double,
        heightMillimeters: Double,
        dotsPerInch: Int,
        widthDots: Int,
        heightDots: Int,
        isFavorite: Bool = false,
        isInStock: Bool = true
    ) {
        self.id = id
        self.name = name
        self.widthMillimeters = widthMillimeters
        self.heightMillimeters = heightMillimeters
        self.dotsPerInch = dotsPerInch
        self.widthDots = widthDots
        self.heightDots = heightDots
        self.isFavorite = isFavorite
        self.isInStock = isInStock
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case widthMillimeters
        case heightMillimeters
        case dotsPerInch
        case widthDots
        case heightDots
        case isFavorite
        case isInStock
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.standard51x25mm300dpi

        id = container.decodeOrDefault(String.self, forKey: .id, default: fallback.id)
        name = container.decodeOrDefault(String.self, forKey: .name, default: fallback.name)
        widthMillimeters = container.decodeOrDefault(Double.self, forKey: .widthMillimeters, default: fallback.widthMillimeters)
        heightMillimeters = container.decodeOrDefault(Double.self, forKey: .heightMillimeters, default: fallback.heightMillimeters)
        dotsPerInch = max(1, container.decodeOrDefault(Int.self, forKey: .dotsPerInch, default: fallback.dotsPerInch))
        widthDots = max(1, container.decodeOrDefault(Int.self, forKey: .widthDots, default: fallback.widthDots))
        heightDots = max(1, container.decodeOrDefault(Int.self, forKey: .heightDots, default: fallback.heightDots))
        isFavorite = container.decodeOrDefault(Bool.self, forKey: .isFavorite, default: false)
        isInStock = container.decodeOrDefault(Bool.self, forKey: .isInStock, default: true)
    }

    static let standard51x25mm300dpi = LabelSize(
        id: "label-51x25mm-300dpi",
        name: "51 x 25 mm",
        widthMillimeters: 51,
        heightMillimeters: 25,
        dotsPerInch: 300,
        widthDots: 602,
        heightDots: 295
    )

    static let dhl4x6Inch300dpi = LabelSize(
        id: "dhl-4x6in-300dpi",
        name: "DHL 4 x 6 inch",
        widthMillimeters: 101.6,
        heightMillimeters: 152.4,
        dotsPerInch: 300,
        widthDots: 1200,
        heightDots: 1800
    )

    static let standardSizes: [LabelSize] = [
        .standard51x25mm300dpi,
        .dhl4x6Inch300dpi
    ]
}
