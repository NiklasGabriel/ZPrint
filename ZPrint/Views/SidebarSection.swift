//
//  SidebarSection.swift
//  ZPrint
//

import Foundation

enum SidebarSection: String, CaseIterable, Identifiable {
    case document
    case variables
    case elements

    var id: String { rawValue }

    var title: String {
        switch self {
        case .document:
            return "Document / Label"
        case .variables:
            return "Variablen"
        case .elements:
            return "Elemente"
        }
    }

    var systemImageName: String {
        switch self {
        case .document:
            return "doc.text"
        case .variables:
            return "curlybraces"
        case .elements:
            return "square.stack.3d.up"
        }
    }
}
