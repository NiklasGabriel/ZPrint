//
//  ZPLEngine.swift
//  ZPrint
//

import Foundation

struct ZPLEngine {
    static func generateLabelZPL(
        document: ZPrintDocument,
        context: VariableEngine.Context = [:]
    ) -> String {
        var lines: [String] = [
            "^XA",
            "^CI28",
            "^PW\(max(1, document.label.widthDots))",
            "^LL\(max(1, document.label.heightDots))",
            "^LH0,0"
        ]

        let variableEngine = VariableEngine(variables: document.variables)

        for element in document.elements {
            switch element {
            case .text(let textElement):
                lines.append(contentsOf: zplLines(for: textElement, variableEngine: variableEngine, context: context))
            case .barcode(let barcodeElement):
                lines.append(contentsOf: zplLines(for: barcodeElement, variableEngine: variableEngine, context: context))
            case .shape(let shapeElement):
                lines.append(contentsOf: zplLines(for: shapeElement))
            }
        }

        lines.append("^XZ")
        return lines.joined(separator: "\n")
    }

    static func generateBatchZPL(document: ZPrintDocument) -> String {
        let contexts = VariableEngine.batchContexts(for: document)

        guard !contexts.isEmpty else {
            return generateLabelZPL(document: document, context: [:])
        }

        return contexts
            .map { generateLabelZPL(document: document, context: $0) }
            .joined(separator: "\n")
    }

    static func diagnostics(for document: ZPrintDocument) -> [ZPLDiagnostic] {
        var diagnostics: [ZPLDiagnostic] = []

        if document.printSettings.counterEnd < document.printSettings.counterStart {
            diagnostics.append(
                ZPLDiagnostic(
                    level: .error,
                    message: "Die Endnummer ist kleiner als die Startnummer."
                )
            )
        }

        for variable in document.variables where variable.type == .sequence {
            let range = document.printSettings.range(for: variable)
            let startValue = range?.startValue ?? variable.startValue
            let endValue = range?.endValue ?? variable.endValue

            if endValue < startValue {
                diagnostics.append(
                    ZPLDiagnostic(
                        level: .error,
                        message: "Die Variable \(variable.name) hat einen Endwert kleiner als den Startwert."
                    )
                )
            }
        }

        for element in document.elements {
            if case .barcode(let barcodeElement) = element,
               barcodeElement.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(
                    ZPLDiagnostic(
                        level: .warning,
                        message: "Ein Barcode hat keinen Wert und wird mit EMPTY ausgegeben."
                    )
                )
            }
        }

        return diagnostics
    }

    private static func zplLines(
        for element: TextLabelElement,
        variableEngine: VariableEngine,
        context: VariableEngine.Context
    ) -> [String] {
        let frame = element.frame
        let renderedText = variableEngine.renderTemplateString(element.text, context: context)
        let height = max(1, element.fontSizeDots)
        let width = max(1, Int(Double(height) * 0.72))
        let orientation = zplOrientation(for: element.rotation)
        let alignment = zplAlignment(for: element.alignment)

        // Zebra Standard-Font A0 unterstützt Fett/Kursiv/Unterstrichen nicht zuverlässig direkt.
        // Diese Attribute bleiben vorerst Editor-/Preview-Formatierung, bis echte Font-Downloads
        // oder robuste Zebra-Font-Mappings eingeführt werden.
        return [
            "^FO\(frame.xDots),\(frame.yDots)",
            "^A0\(orientation),\(height),\(width)",
            "^FB\(max(1, frame.widthDots)),1,0,\(alignment),0",
            "^FH\\^FD\(escapeFieldData(renderedText))^FS"
        ]
    }

    private static func zplLines(
        for element: BarcodeLabelElement,
        variableEngine: VariableEngine,
        context: VariableEngine.Context
    ) -> [String] {
        let frame = element.frame
        let renderedValue = variableEngine
            .renderTemplateString(element.value, context: context)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let value = renderedValue.isEmpty ? "EMPTY" : renderedValue
        let orientation = zplOrientation(for: element.rotation)
        let humanReadable = element.showsHumanReadableText ? "Y" : "N"

        switch element.symbology {
        case .code128:
            return [
                "^FO\(frame.xDots),\(frame.yDots)",
                "^BY\(max(1, element.moduleWidth))",
                "^BC\(orientation),\(max(1, frame.heightDots)),\(humanReadable),N,N",
                "^FH\\^FD\(escapeFieldData(value))^FS"
            ]
        case .ean13, .qrCode:
            return [
                "^FX Unsupported barcode symbology: \(element.symbology.rawValue)"
            ]
        }
    }

    private static func zplLines(for element: ShapeLabelElement) -> [String] {
        let frame = element.frame
        let thickness = max(1, element.strokeWidthDots)

        switch element.shape {
        case .rectangle, .roundedRectangle, .capsule:
            return [
                "^FO\(frame.xDots),\(frame.yDots)",
                "^GB\(max(1, frame.widthDots)),\(max(1, frame.heightDots)),\(element.isFilled ? max(1, frame.heightDots) : thickness),B,\(element.shape == .rectangle ? 0 : 8)^FS"
            ]
        case .line:
            return [
                "^FO\(frame.xDots),\(frame.yDots)",
                "^GB\(max(1, frame.widthDots)),\(max(1, thickness)),\(thickness),B,0^FS"
            ]
        case .ellipse:
            return [
                "^FO\(frame.xDots),\(frame.yDots)",
                "^GE\(max(1, frame.widthDots)),\(max(1, frame.heightDots)),\(thickness),B^FS"
            ]
        case .triangle:
            return [
                "^FX Triangle shapes are not exported yet."
            ]
        }
    }

    private static func zplOrientation(for rotation: LabelElementRotation) -> String {
        switch rotation.degrees {
        case 90:
            return "R"
        case 180:
            return "I"
        case 270:
            return "B"
        default:
            return "N"
        }
    }

    private static func zplAlignment(for alignment: TextElementAlignment) -> String {
        switch alignment {
        case .left:
            return "L"
        case .center:
            return "C"
        case .right:
            return "R"
        }
    }

    private static func escapeFieldData(_ text: String) -> String {
        var escaped = ""

        for character in text {
            switch character {
            case "^":
                escaped += "\\5E"
            case "~":
                escaped += "\\7E"
            case "\\":
                escaped += "\\5C"
            case "\n":
                escaped += "\\0A"
            case "\r":
                escaped += "\\0D"
            default:
                escaped.append(character)
            }
        }

        return escaped
    }
}

struct ZPLDiagnostic: Identifiable, Equatable {
    enum Level: Equatable {
        case warning
        case error
    }

    let id = UUID()
    var level: Level
    var message: String
}
