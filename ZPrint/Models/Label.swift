import Foundation

struct Label: Codable, Hashable {
    var widthDots: Int
    var heightDots: Int
    var dpi: Int

    init(widthDots: Int, heightDots: Int, dpi: Int = DotConversion.defaultDPI) {
        self.widthDots = widthDots
        self.heightDots = heightDots
        self.dpi = dpi
    }

    init(size: LabelSize) {
        self.widthDots = size.widthDots
        self.heightDots = size.heightDots
        self.dpi = size.dpi
    }
}
