import Foundation

enum DotConversion {
    static let defaultDPI = 300

    static func dots(fromMillimeters millimeters: Double, dpi: Int = defaultDPI) -> Int {
        Int((millimeters / 25.4 * Double(dpi)).rounded())
    }

    static func dots(fromInches inches: Double, dpi: Int = defaultDPI) -> Int {
        Int((inches * Double(dpi)).rounded())
    }

    static func millimeters(fromDots dots: Int, dpi: Int = defaultDPI) -> Double {
        Double(dots) / Double(dpi) * 25.4
    }
}
