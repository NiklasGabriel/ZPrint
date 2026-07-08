import Foundation

enum ZPLEngine {
    static func makeZPL(for document: ZPrintDocument, variableValues: [String: String]) -> String {
        var lines: [String] = [
            "^XA",
            "^PW\(document.labelSize.widthDots)",
            "^LL\(document.labelSize.heightDots)"
        ]

        for element in document.elements {
            lines.append(contentsOf: makeZPL(for: element, variableValues: variableValues))
        }

        lines.append("^XZ")
        return lines.joined(separator: "\n")
    }

    private static func makeZPL(for element: LabelElement, variableValues: [String: String]) -> [String] {
        switch element {
        case .text(let textElement):
            let resolvedText = VariableEngine.resolve(textElement.text, values: variableValues)
            return [
                "^FO\(textElement.xDots),\(textElement.yDots)",
                "^A0N,\(textElement.fontHeightDots),\(textElement.fontHeightDots)",
                "^FD\(resolvedText)^FS"
            ]

        case .barcode(let barcodeElement):
            let resolvedValue = VariableEngine.resolve(barcodeElement.value, values: variableValues)
            return [
                "^FO\(barcodeElement.xDots),\(barcodeElement.yDots)",
                "^BCN,\(barcodeElement.heightDots),Y,N,N",
                "^FD\(resolvedValue)^FS"
            ]
        }
    }
}
