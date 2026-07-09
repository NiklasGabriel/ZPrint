//
//  DotViewScale.swift
//  ZPrint
//

import CoreGraphics

struct DotViewScale {
    let pointsPerDot: CGFloat

    init(zoomScale: Double) {
        pointsPerDot = CGFloat(max(0.25, min(zoomScale, 3.0)))
    }

    func points(fromDots dots: Int) -> CGFloat {
        CGFloat(dots) * pointsPerDot
    }

    func dots(fromPoints points: CGFloat) -> Int {
        Int((points / pointsPerDot).rounded())
    }

    func size(for labelSize: LabelSize) -> CGSize {
        CGSize(
            width: points(fromDots: labelSize.widthDots),
            height: points(fromDots: labelSize.heightDots)
        )
    }

    func rect(for frame: LabelElementFrame) -> CGRect {
        CGRect(
            x: points(fromDots: frame.xDots),
            y: points(fromDots: frame.yDots),
            width: points(fromDots: frame.widthDots),
            height: points(fromDots: frame.heightDots)
        )
    }
}
