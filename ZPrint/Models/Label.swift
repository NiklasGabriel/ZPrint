import Foundation

struct Label: Codable, Hashable {
    var id: String
    var name: String
    var widthMm: Double
    var heightMm: Double
    var dpi: Int
    var widthDots: Int
    var heightDots: Int

    init(
        id: String,
        name: String,
        widthMm: Double,
        heightMm: Double,
        dpi: Int,
        widthDots: Int,
        heightDots: Int
    ) {
        self.id = id
        self.name = name
        self.widthMm = widthMm
        self.heightMm = heightMm
        self.dpi = dpi
        self.widthDots = widthDots
        self.heightDots = heightDots
    }

    init(size: LabelSize) {
        self.id = size.id
        self.name = size.name
        self.widthMm = size.widthMm
        self.heightMm = size.heightMm
        self.dpi = size.dpi
        self.widthDots = size.widthDots
        self.heightDots = size.heightDots
    }
}
