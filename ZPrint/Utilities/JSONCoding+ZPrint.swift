//
//  JSONCoding+ZPrint.swift
//  ZPrint
//

import Foundation

extension JSONEncoder {
    static var zprint: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        return encoder
    }
}

extension JSONDecoder {
    static var zprint: JSONDecoder {
        JSONDecoder()
    }
}
