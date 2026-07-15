//
//  CodableDefaults+ZPrint.swift
//  ZPrint
//

import Foundation

extension KeyedDecodingContainer {
    func decodeOrDefault<Value: Decodable>(
        _ type: Value.Type,
        forKey key: Key,
        default defaultValue: Value
    ) -> Value {
        (try? decodeIfPresent(type, forKey: key)) ?? defaultValue
    }

    func decodeLossyArray<Element: Decodable>(
        _ type: [Element].Type,
        forKey key: Key,
        default defaultValue: [Element] = []
    ) -> [Element] {
        guard let wrappers = try? decodeIfPresent([LossyDecodable<Element>].self, forKey: key) else {
            return defaultValue
        }

        return wrappers.compactMap(\.value)
    }
}

private struct LossyDecodable<Value: Decodable>: Decodable {
    var value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
