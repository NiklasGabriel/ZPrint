import Foundation

struct ZPLGenerationContext {
    var variables: [String: String]

    init(variables: [String: String] = [:]) {
        self.variables = variables
    }

    static let empty = ZPLGenerationContext()
}

enum ZPLEngine {
    static func generateZPL(document: ZPrintDocument, context: ZPLGenerationContext = .empty) -> String {
        var lines: [String] = [
            "^XA",
            "^CI28",
            "^PW\(document.label.widthDots)",
            "^LL\(document.label.heightDots)",
            "^LH0,0"
        ]

        for element in document.elements {
            lines.append(contentsOf: generateZPL(for: element, context: context))
        }

        lines.append("^XZ")
        return lines.joined(separator: "\n")
    }

    static func makeZPL(for document: ZPrintDocument, variableValues: [String: String]) -> String {
        generateZPL(document: document, context: ZPLGenerationContext(variables: variableValues))
    }

    private static func generateZPL(for element: LabelElement, context: ZPLGenerationContext) -> [String] {
        switch element {
        case .text(let textElement):
            let resolvedText = resolveAndEscape(textElement.text, context: context)
            let fontWidth = textElement.fontSizeDots
            return [
                "^FO\(textElement.xDots),\(textElement.yDots)",
                "^A0N,\(textElement.fontSizeDots),\(fontWidth)",
                "^FD\(resolvedText)^FS"
            ]

        case .barcode(let barcodeElement):
            let resolvedValue = resolveAndEscape(barcodeElement.value, context: context)
            let humanReadable = barcodeElement.humanReadable ? "Y" : "N"
            return [
                "^FO\(barcodeElement.xDots),\(barcodeElement.yDots)",
                "^BY\(barcodeElement.moduleWidth)",
                "^BCN,\(barcodeElement.heightDots),\(humanReadable),N,N",
                "^FD\(resolvedValue)^FS"
            ]
        }
    }

    private static func resolveAndEscape(_ template: String, context: ZPLGenerationContext) -> String {
        let resolved = VariableEngine.resolve(template, values: context.variables)
        return escapeFieldData(resolved)
    }

    private static func escapeFieldData(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "^", with: "\\5E")
            .replacingOccurrences(of: "~", with: "\\7E")
    }
}
