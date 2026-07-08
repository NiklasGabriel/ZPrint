import Foundation

struct LabelSize: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var widthDots: Int
    var heightDots: Int
    var dpi: Int

    init(id: String, name: String, widthDots: Int, heightDots: Int, dpi: Int = DotConversion.defaultDPI) {
        self.id = id
        self.name = name
        self.widthDots = widthDots
        self.heightDots = heightDots
        self.dpi = dpi
    }

    static let label51x25mm = LabelSize(
        id: "51x25mm",
        name: "51 x 25 mm",
        widthDots: DotConversion.dots(fromMillimeters: 51),
        heightDots: DotConversion.dots(fromMillimeters: 25)
    )

    static let dhl4x6Inch = LabelSize(
        id: "dhl-4x6-inch",
        name: "DHL 4 x 6 inch",
        widthDots: DotConversion.dots(fromInches: 4),
        heightDots: DotConversion.dots(fromInches: 6)
    )

    static let presets: [LabelSize] = [label51x25mm, dhl4x6Inch]
}
