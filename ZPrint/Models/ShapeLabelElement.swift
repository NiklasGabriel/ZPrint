//
//  ShapeLabelElement.swift
//  ZPrint
//

import Foundation

struct ShapeLabelElement: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var frame: LabelElementFrame
    var shape: LabelShapeKind
    var strokeWidthDots: Int
    var isFilled: Bool

    init(
        id: UUID = UUID(),
        name: String = "Shape",
        frame: LabelElementFrame = .zero,
        shape: LabelShapeKind = .rectangle,
        strokeWidthDots: Int = 2,
        isFilled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.shape = shape
        self.strokeWidthDots = strokeWidthDots
        self.isFilled = isFilled
    }
}

enum LabelShapeKind: String, Codable, Equatable, Sendable {
    case rectangle
    case ellipse
    case line
}
