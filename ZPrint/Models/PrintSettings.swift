//
//  PrintSettings.swift
//  ZPrint
//

import Foundation

struct PrintSettings: Codable, Equatable, Sendable {
    var counterStart: Int
    var counterEnd: Int

    static let standard = PrintSettings(
        counterStart: 1,
        counterEnd: 1
    )
}
