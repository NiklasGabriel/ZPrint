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

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        widthMillimeters = try container.decode(Double.self, forKey: .widthMillimeters)
        heightMillimeters = try container.decode(Double.self, forKey: .heightMillimeters)
        dotsPerInch = try container.decode(Int.self, forKey: .dotsPerInch)
        widthDots = try container.decode(Int.self, forKey: .widthDots)
        heightDots = try container.decode(Int.self, forKey: .heightDots)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isInStock = try container.decodeIfPresent(Bool.self, forKey: .isInStock) ?? true
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
