//
//  Code128Barcode.swift
//  ZPrint
//

import Foundation

struct Code128Barcode {
    struct Segment: Identifiable, Equatable {
        let id = UUID()
        let isBar: Bool
        let widthModules: Int
    }

    static func segments(for value: String) -> [Segment] {
        guard !value.isEmpty else {
            return []
        }

        let codeValues = code128BValues(for: value)
        let checksum = checksumValue(for: codeValues)
        let sequence = [104] + codeValues + [checksum, 106]

        return sequence.flatMap { value in
            patternSegments(for: patterns[value])
        }
    }

    private static func code128BValues(for value: String) -> [Int] {
        value.unicodeScalars.map { scalar in
            let ascii = Int(scalar.value)

            if ascii >= 32 && ascii <= 127 {
                return ascii - 32
            }

            return 31
        }
    }

    private static func checksumValue(for codeValues: [Int]) -> Int {
        var checksum = 104

        for (index, value) in codeValues.enumerated() {
            checksum += value * (index + 1)
        }

        return checksum % 103
    }

    private static func patternSegments(for pattern: String) -> [Segment] {
        pattern.enumerated().compactMap { index, character in
            guard let width = Int(String(character)) else {
                return nil
            }

            return Segment(
                isBar: index.isMultiple(of: 2),
                widthModules: width
            )
        }
    }

    private static let patterns = [
        "212222", "222122", "222221", "121223", "121322", "131222",
        "122213", "122312", "132212", "221213", "221312", "231212",
        "112232", "122132", "122231", "113222", "123122", "123221",
        "223211", "221132", "221231", "213212", "223112", "312131",
        "311222", "321122", "321221", "312212", "322112", "322211",
        "212123", "212321", "232121", "111323", "131123", "131321",
        "112313", "132113", "132311", "211313", "231113", "231311",
        "112133", "112331", "132131", "113123", "113321", "133121",
        "313121", "211331", "231131", "213113", "213311", "213131",
        "311123", "311321", "331121", "312113", "312311", "332111",
        "314111", "221411", "431111", "111224", "111422", "121124",
        "121421", "141122", "141221", "112214", "112412", "122114",
        "122411", "142112", "142211", "241211", "221114", "413111",
        "241112", "134111", "111242", "121142", "121241", "114212",
        "124112", "124211", "411212", "421112", "421211", "212141",
        "214121", "412121", "111143", "111341", "131141", "114113",
        "114311", "411113", "411311", "113141", "114131", "311141",
        "411131", "211412", "211214", "211232", "2331112"
    ]
}
