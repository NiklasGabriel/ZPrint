//
//  RibbonTab.swift
//  ZPrint
//

import Foundation

enum RibbonTab: String, CaseIterable, Identifiable {
    case home
    case insert
    case layout
    case variables
    case preview
    case print

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Start"
        case .insert:
            return "Einfügen"
        case .layout:
            return "Layout"
        case .variables:
            return "Variablen"
        case .preview:
            return "Vorschau"
        case .print:
            return "Drucken"
        }
    }
}
