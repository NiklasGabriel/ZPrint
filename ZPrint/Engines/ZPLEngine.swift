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

        if let bitmapLayer = ZPLBitmapLayerRenderer.renderNonBarcodeLayer(
            document: document,
            context: context
        ) {
            lines.append(contentsOf: [
                "^FO\(bitmapLayer.xDots),\(bitmapLayer.yDots)",
                bitmapLayer.zplCommand
            ])
        }

        for element in document.elements {
            if case .barcode(let barcodeElement) = element {
                lines.append(contentsOf: zplLines(for: barcodeElement, variableEngine: variableEngine, context: context))
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

        if let runningRange = document.printSettings.runningRange(for: document.variables),
           runningRange.endValue < runningRange.startValue {
            diagnostics.append(
                ZPLDiagnostic(
                    level: .error,
                    message: "Die Endnummer ist kleiner als die Startnummer."
                )
            )
        } else if document.printSettings.runningRange(for: document.variables) == nil,
                  document.printSettings.counterEnd < document.printSettings.counterStart {
            diagnostics.append(
                ZPLDiagnostic(
                    level: .error,
                    message: "Die Endnummer ist kleiner als die Startnummer."
                )
            )
        }

        if document.printSettings.runningVariable(in: document.variables)?.type != .sequence,
           !document.variables.isEmpty {
            diagnostics.append(
                ZPLDiagnostic(
                    level: .warning,
                    message: "Es ist keine Sequenz-Laufvariable aktiv."
                )
            )
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

        for variable in document.variables where variable.type == .tableLookup {
            guard let lookup = variable.tableLookup,
                  let sourceVariableID = lookup.sourceVariableID,
                  document.variables.contains(where: { $0.id == sourceVariableID && $0.type != .tableLookup }),
                  let tableSourceID = lookup.tableSourceID,
                  let tableSource = document.tableSources.first(where: { $0.id == tableSourceID }),
                  let sheet = tableSource.sheet(named: lookup.sheetName),
                  sheet.headers.contains(lookup.keyColumn),
                  sheet.headers.contains(lookup.valueColumn) else {
                diagnostics.append(
                    ZPLDiagnostic(
                        level: .warning,
                        message: "Die Tabellenvariable \"\(variable.name)\" ist nicht vollständig verknüpft."
                    )
                )
                continue
            }

            let duplicateCount = sheet.duplicateKeyCount(
                in: lookup.keyColumn,
                caseSensitive: lookup.caseSensitive
            )
            if duplicateCount > 0 {
                diagnostics.append(
                    ZPLDiagnostic(
                        level: .warning,
                        message: "Die Tabellenvariable \"\(variable.name)\" enthält \(duplicateCount) doppelte Schlüssel; der erste Treffer wird verwendet."
                    )
                )
            }
        }

        return diagnostics
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
        let humanReadable = "N"
        let moduleWidth = Code128Barcode.moduleWidthFitting(
            value: value,
            widthDots: frame.widthDots,
            fallbackModuleWidth: element.moduleWidth
        )
        let humanReadableReserve = element.showsHumanReadableText ? min(28, max(14, frame.heightDots / 4)) : 0
        let barHeight = max(1, frame.heightDots - humanReadableReserve)

        switch element.symbology {
        case .code128:
            return [
                "^FO\(frame.xDots),\(frame.yDots)",
                "^BY\(moduleWidth)",
                "^BC\(orientation),\(barHeight),\(humanReadable),N,N",
                "^FH\\^FD\(escapeFieldData(value))^FS"
            ]
        case .ean13, .qrCode:
            return [
                "^FX Unsupported barcode symbology: \(element.symbology.rawValue)"
            ]
        }
    }

    private static func zplOrientation(for rotation: LabelElementRotation) -> String {
        switch rotation.degrees {
        case 90:
            return "B"
        case 180:
            return "I"
        case 270:
            return "R"
        default:
            return "N"
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
