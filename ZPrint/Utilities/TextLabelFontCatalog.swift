//
//  TextLabelFontCatalog.swift
//  ZPrint
//

import AppKit
import SwiftUI

enum TextLabelFontCatalog {
    static let systemFamilyName = ""

    static let fontFamilyNames: [String] = {
        let families = NSFontManager.shared.availableFontFamilies
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return [systemFamilyName] + families
    }()

    static func displayName(for familyName: String) -> String {
        familyName.isEmpty ? "System" : familyName
    }

    static func swiftUIFont(
        familyName: String,
        size: CGFloat,
        isBold: Bool
    ) -> Font {
        let clampedSize = max(1, size)

        guard !familyName.isEmpty else {
            return .system(
                size: clampedSize,
                weight: isBold ? .semibold : .regular
            )
        }

        return Font
            .custom(familyName, size: clampedSize)
            .weight(isBold ? .semibold : .regular)
    }

    static func nsFont(
        familyName: String,
        size: CGFloat,
        isBold: Bool,
        isItalic: Bool
    ) -> NSFont {
        let clampedSize = max(1, size)

        guard !familyName.isEmpty else {
            return NSFont.systemFont(
                ofSize: clampedSize,
                weight: isBold ? .semibold : .regular
            )
        }

        var traits: NSFontTraitMask = []
        if isBold {
            traits.insert(.boldFontMask)
        }
        if isItalic {
            traits.insert(.italicFontMask)
        }

        return NSFontManager.shared.font(
            withFamily: familyName,
            traits: traits,
            weight: isBold ? 9 : 5,
            size: clampedSize
        ) ?? NSFont(name: familyName, size: clampedSize)
            ?? NSFont.systemFont(
                ofSize: clampedSize,
                weight: isBold ? .semibold : .regular
            )
    }
}
