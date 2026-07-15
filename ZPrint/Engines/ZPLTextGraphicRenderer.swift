//
//  ZPLTextGraphicRenderer.swift
//  ZPrint
//

import AppKit
import Foundation

struct ZPLGraphicField {
    var xDots: Int
    var yDots: Int
    var widthDots: Int
    var heightDots: Int
    var bytesPerRow: Int
    var data: [UInt8]

    var zplCommand: String {
        let totalBytes = data.count
        return "^GFA,\(totalBytes),\(totalBytes),\(bytesPerRow),\(hexadecimalData)^FS"
    }

    private var hexadecimalData: String {
        let digits = Array("0123456789ABCDEF".utf8)
        var result = [UInt8]()
        result.reserveCapacity(data.count * 2)

        for byte in data {
            result.append(digits[Int(byte >> 4)])
            result.append(digits[Int(byte & 0x0F)])
        }

        return String(bytes: result, encoding: .ascii) ?? ""
    }
}

enum ZPLBitmapLayerRenderer {
    static func renderNonBarcodeLayer(
        document: ZPrintDocument,
        context: VariableEngine.Context
    ) -> ZPLGraphicField? {
        let width = max(1, document.label.widthDots)
        let height = max(1, document.label.heightDots)
        let variableEngine = VariableEngine(variables: document.variables)

        guard let representation = fixedSizeBitmapRepresentation(width: width, height: height, draw: {
            NSColor.clear.setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()

            for element in document.elements {
                switch element {
                case .text(let textElement):
                    let text = variableEngine.renderTemplateString(textElement.text, context: context)
                    drawTextElement(textElement, text: text)
                case .barcode(let barcodeElement):
                    let value = variableEngine.renderTemplateString(barcodeElement.value, context: context)
                    drawBarcodeReadableText(barcodeElement, value: value)
                case .shape(let shapeElement):
                    drawShapeElement(shapeElement)
                case .image(let imageElement):
                    drawImageElement(imageElement)
                }
            }
        }) else {
            return nil
        }

        let bits = sampledMonochromeBits(
            from: representation,
            width: width,
            height: height
        )

        guard let bounds = contentBounds(bits: bits, width: width, height: height) else {
            return nil
        }

        let croppedWidth = bounds.maxX - bounds.minX + 1
        let croppedHeight = bounds.maxY - bounds.minY + 1
        let croppedBits = cropBits(
            bits,
            sourceWidth: width,
            bounds: bounds,
            croppedWidth: croppedWidth,
            croppedHeight: croppedHeight
        )

        return ZPLGraphicField(
            xDots: bounds.minX,
            yDots: bounds.minY,
            widthDots: croppedWidth,
            heightDots: croppedHeight,
            bytesPerRow: bytesPerRow(for: croppedWidth),
            data: packedRows(bits: croppedBits, width: croppedWidth, height: croppedHeight)
        )
    }

    private static func fixedSizeBitmapRepresentation(
        width: Int,
        height: Int,
        draw: () -> Void
    ) -> NSBitmapImageRep? {
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [.alphaFirst],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        representation.size = NSSize(width: width, height: height)

        guard let bitmapContext = NSGraphicsContext(bitmapImageRep: representation) else {
            return nil
        }

        let graphicsContext = NSGraphicsContext(cgContext: bitmapContext.cgContext, flipped: true)
        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = graphicsContext

        draw()
        graphicsContext.flushGraphics()
        NSGraphicsContext.current = previousContext

        return representation
    }

    private static func sampledMonochromeBits(
        from representation: NSBitmapImageRep,
        width: Int,
        height: Int
    ) -> [Bool] {
        var bits = Array(repeating: false, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                guard let color = representation
                    .colorAt(
                        x: min(x, max(0, representation.pixelsWide - 1)),
                        y: min(height - 1 - y, max(0, representation.pixelsHigh - 1))
                    )?
                    .usingColorSpace(.deviceRGB) else {
                    continue
                }

                let luminance = 0.2126 * color.redComponent
                    + 0.7152 * color.greenComponent
                    + 0.0722 * color.blueComponent
                bits[y * width + x] = color.alphaComponent > 0.08 && luminance < 0.72
            }
        }

        return bits
    }

    private static func drawTextElement(
        _ element: TextLabelElement,
        text: String
    ) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let rect = nsRect(for: element.frame)
        drawRotated(frame: element.frame, rotation: element.rotation) {
            let attributedText = attributedString(for: text, element: element)
            let measuredHeight = ceil(
                attributedText.boundingRect(
                    with: NSSize(width: rect.width, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                ).height
            )
            let drawHeight = min(rect.height, max(1, measuredHeight))
            let drawRect = NSRect(
                x: rect.minX,
                y: rect.minY + max(0, (rect.height - drawHeight) / 2),
                width: rect.width,
                height: drawHeight
            )

            attributedText.draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine]
            )
        }
    }

    private static func drawShapeElement(_ element: ShapeLabelElement) {
        let rect = nsRect(for: element.frame)

        drawRotated(frame: element.frame, rotation: element.rotation) {
            let path = shapePath(for: element.shape, in: rect)

            if element.isFilled {
                nsColor(from: element.fillColor).setFill()
                path.fill()
            }

            if element.hasStroke {
                nsColor(from: element.strokeColor).setStroke()
                path.lineWidth = CGFloat(max(1, element.strokeWidthDots))
                path.stroke()
            }
        }
    }

    private static func drawImageElement(_ element: ImageLabelElement) {
        guard let image = LabelImageImporter.image(from: element.imageData) else {
            return
        }

        let rect = nsRect(for: element.frame)
        drawRotated(frame: element.frame, rotation: element.rotation) {
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }
    }

    private static func drawBarcodeReadableText(
        _ element: BarcodeLabelElement,
        value: String
    ) {
        guard element.showsHumanReadableText else {
            return
        }

        let renderedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "EMPTY" : value
        let frame = element.frame
        let readableHeight = min(28, max(14, frame.heightDots / 4))
        let textRect = NSRect(
            x: frame.xDots,
            y: frame.yDots + max(0, frame.heightDots - readableHeight),
            width: max(1, frame.widthDots),
            height: max(1, readableHeight)
        )

        drawRotated(frame: frame, rotation: element.rotation) {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byTruncatingTail

            let fontSize = CGFloat(max(8, readableHeight - 6))
            let attributedText = NSAttributedString(
                string: renderedValue,
                attributes: [
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: paragraphStyle
                ]
            )

            let measuredHeight = ceil(
                attributedText.boundingRect(
                    with: NSSize(width: textRect.width, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                ).height
            )
            let drawHeight = min(textRect.height, max(1, measuredHeight))
            let drawRect = NSRect(
                x: textRect.minX,
                y: textRect.minY + max(0, (textRect.height - drawHeight) / 2),
                width: textRect.width,
                height: drawHeight
            )

            attributedText.draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine]
            )
        }
    }

    private static func drawRotated(
        frame: LabelElementFrame,
        rotation: LabelElementRotation,
        draw: () -> Void
    ) {
        guard let context = NSGraphicsContext.current else {
            draw()
            return
        }

        context.saveGraphicsState()

        if rotation.degrees != 0 {
            let rect = nsRect(for: frame)
            let transform = NSAffineTransform()
            transform.translateX(by: rect.midX, yBy: rect.midY)
            transform.rotate(byDegrees: -CGFloat(rotation.degrees))
            transform.translateX(by: -rect.midX, yBy: -rect.midY)
            transform.concat()
        }

        draw()
        context.restoreGraphicsState()
    }

    private static func attributedString(
        for text: String,
        element: TextLabelElement
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = nsTextAlignment(for: element.alignment)
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let font = TextLabelFontCatalog.nsFont(
            familyName: element.fontFamilyName,
            size: CGFloat(max(1, element.fontSizeDots)),
            isBold: element.isBold,
            isItalic: element.isItalic
        )

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        if element.isUnderlined {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func shapePath(
        for shape: LabelShapeKind,
        in rect: NSRect
    ) -> NSBezierPath {
        switch shape {
        case .rectangle:
            return NSBezierPath(rect: rect)
        case .roundedRectangle:
            return NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        case .ellipse:
            return NSBezierPath(ovalIn: rect)
        case .capsule:
            let radius = min(rect.width, rect.height) / 2
            return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        case .triangle:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.midX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
            path.close()
            return path
        case .line:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.midY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }

    private static func nsRect(for frame: LabelElementFrame) -> NSRect {
        NSRect(
            x: frame.xDots,
            y: frame.yDots,
            width: max(1, frame.widthDots),
            height: max(1, frame.heightDots)
        )
    }

    private static func nsColor(from color: LabelElementColor) -> NSColor {
        NSColor(
            calibratedRed: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }

    private static func contentBounds(
        bits: [Bool],
        width: Int,
        height: Int
    ) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width where bits[y * width + x] {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        return (minX, minY, maxX, maxY)
    }

    private static func cropBits(
        _ bits: [Bool],
        sourceWidth: Int,
        bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int),
        croppedWidth: Int,
        croppedHeight: Int
    ) -> [Bool] {
        var croppedBits = Array(repeating: false, count: croppedWidth * croppedHeight)

        for y in 0..<croppedHeight {
            for x in 0..<croppedWidth {
                let sourceX = bounds.minX + x
                let sourceY = bounds.minY + y
                croppedBits[y * croppedWidth + x] = bits[sourceY * sourceWidth + sourceX]
            }
        }

        return croppedBits
    }

    private static func packedRows(
        bits: [Bool],
        width: Int,
        height: Int
    ) -> [UInt8] {
        let rowBytes = bytesPerRow(for: width)
        var data = Array(repeating: UInt8(0), count: rowBytes * height)

        for y in 0..<height {
            for x in 0..<width where bits[y * width + x] {
                let byteIndex = y * rowBytes + x / 8
                let bitMask = UInt8(0x80 >> UInt8(x % 8))
                data[byteIndex] |= bitMask
            }
        }

        return data
    }

    private static func bytesPerRow(for width: Int) -> Int {
        max(1, Int(ceil(Double(width) / 8)))
    }

    private static func nsTextAlignment(for alignment: TextElementAlignment) -> NSTextAlignment {
        switch alignment {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        }
    }
}
