import Foundation

struct LabelSize: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var widthMm: Double
    var heightMm: Double
    var dpi: Int
    var widthDots: Int
    var heightDots: Int

    init(id: String, name: String, widthMm: Double, heightMm: Double, dpi: Int = DotConversion.defaultDPI) {
        self.id = id
        self.name = name
        self.widthMm = widthMm
        self.heightMm = heightMm
        self.dpi = dpi
        self.widthDots = DotConversion.dots(fromMillimeters: widthMm, dpi: dpi)
        self.heightDots = DotConversion.dots(fromMillimeters: heightMm, dpi: dpi)
    }

    init(id: String, name: String, widthMm: Double, heightMm: Double, dpi: Int, widthDots: Int, heightDots: Int) {
        self.id = id
        self.name = name
        self.widthMm = widthMm
        self.heightMm = heightMm
        self.dpi = dpi
        self.widthDots = widthDots
        self.heightDots = heightDots
    }

    static let label51x25mm = LabelSize(
        id: "51x25-300",
        name: "51 × 25 mm",
        widthMm: 51,
        heightMm: 25,
        dpi: 300
    )

    static let dhl4x6Inch = LabelSize(
        id: "dhl-4x6-300",
        name: "DHL 4 × 6 inch",
        widthMm: 101.6,
        heightMm: 152.4,
        dpi: 300
    )

    static let presets: [LabelSize] = [label51x25mm, dhl4x6Inch]

    static func preset(for id: String) -> LabelSize? {
        presets.first { $0.id == id }
    }

    static func displayName(for id: String) -> String {
        preset(for: id)?.name ?? id
    }
}
