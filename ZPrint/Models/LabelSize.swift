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
        name: "51 x 25 mm (2.00x1.00\")",
        widthMillimeters: 51,
        heightMillimeters: 25,
        dotsPerInch: 300,
        widthDots: 602,
        heightDots: 295
    )

    static let dhl4x6Inch300dpi = LabelSize(
        id: "dhl-4x6in-300dpi",
        name: "102 x 152 mm (4.00x6.00\")",
        widthMillimeters: 101.6,
        heightMillimeters: 152.4,
        dotsPerInch: 300,
        widthDots: 1200,
        heightDots: 1800
    )

    static func zebraInchSize(
        widthInches: Double,
        heightInches: Double,
        displayMillimeters: (width: Int, height: Int)? = nil
    ) -> LabelSize {
        let widthMillimeters = widthInches * 25.4
        let heightMillimeters = heightInches * 25.4
        let roundedMillimeters = displayMillimeters
            ?? (Int(widthMillimeters.rounded()), Int(heightMillimeters.rounded()))
        let normalizedWidth = Self.idComponent(for: widthInches)
        let normalizedHeight = Self.idComponent(for: heightInches)

        return LabelSize(
            id: "zebra-\(normalizedWidth)x\(normalizedHeight)in-300dpi",
            name: "\(roundedMillimeters.width) x \(roundedMillimeters.height) mm (\(Self.inchDisplay(widthInches))x\(Self.inchDisplay(heightInches))\")",
            widthMillimeters: Double(roundedMillimeters.width),
            heightMillimeters: Double(roundedMillimeters.height),
            dotsPerInch: 300,
            widthDots: Int((widthInches * 300).rounded()),
            heightDots: Int((heightInches * 300).rounded())
        )
    }

    private static func idComponent(for inches: Double) -> String {
        String(format: "%.2f", inches)
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "-00", with: "")
    }

    private static func inchDisplay(_ inches: Double) -> String {
        String(format: "%.2f", inches)
    }

    static let standardSizes: [LabelSize] = [
        .zebraInchSize(widthInches: 1.25, heightInches: 0.25, displayMillimeters: (32, 6)),
        .zebraInchSize(widthInches: 1.25, heightInches: 2.25, displayMillimeters: (32, 57)),

        .zebraInchSize(widthInches: 1.50, heightInches: 0.25, displayMillimeters: (38, 6)),
        .zebraInchSize(widthInches: 1.50, heightInches: 0.50, displayMillimeters: (38, 13)),
        .zebraInchSize(widthInches: 1.50, heightInches: 1.00, displayMillimeters: (38, 25)),
        .zebraInchSize(widthInches: 1.50, heightInches: 2.00, displayMillimeters: (38, 51)),

        .zebraInchSize(widthInches: 2.00, heightInches: 0.37, displayMillimeters: (51, 9)),
        .zebraInchSize(widthInches: 2.00, heightInches: 0.50, displayMillimeters: (51, 13)),
        .standard51x25mm300dpi,
        .zebraInchSize(widthInches: 2.00, heightInches: 1.25, displayMillimeters: (51, 32)),
        .zebraInchSize(widthInches: 2.00, heightInches: 4.00, displayMillimeters: (51, 102)),
        .zebraInchSize(widthInches: 2.00, heightInches: 5.50, displayMillimeters: (51, 140)),

        .zebraInchSize(widthInches: 2.25, heightInches: 0.50, displayMillimeters: (57, 13)),
        .zebraInchSize(widthInches: 2.25, heightInches: 1.25, displayMillimeters: (57, 32)),
        .zebraInchSize(widthInches: 2.25, heightInches: 4.00, displayMillimeters: (57, 102)),
        .zebraInchSize(widthInches: 2.25, heightInches: 5.50, displayMillimeters: (57, 140)),
        .zebraInchSize(widthInches: 2.38, heightInches: 5.50, displayMillimeters: (60, 140)),
        .zebraInchSize(widthInches: 2.50, heightInches: 1.00, displayMillimeters: (64, 25)),
        .zebraInchSize(widthInches: 2.50, heightInches: 2.00, displayMillimeters: (64, 51)),
        .zebraInchSize(widthInches: 2.75, heightInches: 1.25, displayMillimeters: (70, 32)),

        .zebraInchSize(widthInches: 3.00, heightInches: 1.00, displayMillimeters: (76, 25)),
        .zebraInchSize(widthInches: 3.00, heightInches: 1.25, displayMillimeters: (76, 32)),
        .zebraInchSize(widthInches: 3.00, heightInches: 2.00, displayMillimeters: (76, 51)),
        .zebraInchSize(widthInches: 3.00, heightInches: 3.00, displayMillimeters: (76, 76)),
        .zebraInchSize(widthInches: 3.00, heightInches: 5.00, displayMillimeters: (76, 127)),

        .zebraInchSize(widthInches: 3.25, heightInches: 2.00, displayMillimeters: (83, 51)),
        .zebraInchSize(widthInches: 3.25, heightInches: 5.00, displayMillimeters: (83, 127)),
        .zebraInchSize(widthInches: 3.25, heightInches: 5.50, displayMillimeters: (83, 140)),
        .zebraInchSize(widthInches: 3.25, heightInches: 5.83, displayMillimeters: (83, 148)),
        .zebraInchSize(widthInches: 3.25, heightInches: 7.83, displayMillimeters: (83, 199)),
        .zebraInchSize(widthInches: 3.50, heightInches: 1.00, displayMillimeters: (89, 25)),

        .zebraInchSize(widthInches: 4.00, heightInches: 1.00, displayMillimeters: (102, 25)),
        .zebraInchSize(widthInches: 4.00, heightInches: 2.00, displayMillimeters: (102, 51)),
        .zebraInchSize(widthInches: 4.00, heightInches: 2.50, displayMillimeters: (102, 64)),
        .zebraInchSize(widthInches: 4.00, heightInches: 3.00, displayMillimeters: (102, 76)),
        .zebraInchSize(widthInches: 4.00, heightInches: 4.00, displayMillimeters: (102, 102)),
        .zebraInchSize(widthInches: 4.00, heightInches: 5.00, displayMillimeters: (102, 127)),
        .dhl4x6Inch300dpi,
        .zebraInchSize(widthInches: 4.00, heightInches: 6.50, displayMillimeters: (102, 165)),
        .zebraInchSize(widthInches: 4.00, heightInches: 13.00, displayMillimeters: (102, 330)),

        .zebraInchSize(widthInches: 6.00, heightInches: 1.00, displayMillimeters: (152, 25)),
        .zebraInchSize(widthInches: 6.00, heightInches: 2.00, displayMillimeters: (152, 51)),
        .zebraInchSize(widthInches: 6.00, heightInches: 3.00, displayMillimeters: (152, 76)),
        .zebraInchSize(widthInches: 6.00, heightInches: 4.00, displayMillimeters: (152, 102)),
        .zebraInchSize(widthInches: 6.00, heightInches: 5.00, displayMillimeters: (152, 127)),
        .zebraInchSize(widthInches: 6.00, heightInches: 6.00, displayMillimeters: (152, 152)),
        .zebraInchSize(widthInches: 6.00, heightInches: 6.50, displayMillimeters: (152, 165)),

        .zebraInchSize(widthInches: 8.00, heightInches: 1.00, displayMillimeters: (203, 25)),
        .zebraInchSize(widthInches: 8.00, heightInches: 2.00, displayMillimeters: (203, 51)),
        .zebraInchSize(widthInches: 8.00, heightInches: 3.00, displayMillimeters: (203, 76)),
        .zebraInchSize(widthInches: 8.00, heightInches: 4.00, displayMillimeters: (203, 102)),
        .zebraInchSize(widthInches: 8.00, heightInches: 5.00, displayMillimeters: (203, 127)),
        .zebraInchSize(widthInches: 8.00, heightInches: 6.00, displayMillimeters: (203, 152)),
        .zebraInchSize(widthInches: 8.00, heightInches: 6.50, displayMillimeters: (203, 165))
    ]
}
