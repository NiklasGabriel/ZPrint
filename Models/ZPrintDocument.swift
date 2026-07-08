import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let zprint = UTType(exportedAs: "com.niklasgabriel.zprint")
}

struct ZPrintDocument: FileDocument, Codable {
    static var readableContentTypes: [UTType] { [.zprint] }

    var labelSize: LabelSize
    var elements: [LabelElement]
    var printSettings: PrintSettings
    var variables: [VariableDefinition]

    init(
        labelSize: LabelSize = .label51x25mm,
        elements: [LabelElement] = [
            .text(TextLabelElement(xDots: 40, yDots: 40, text: "{{name}}")),
            .barcode(BarcodeLabelElement(xDots: 40, yDots: 110, value: "{{number:00000}}"))
        ],
        printSettings: PrintSettings = PrintSettings(),
        variables: [VariableDefinition] = [
            VariableDefinition(name: "name", sampleValue: "Demo"),
            VariableDefinition(name: "number", sampleValue: "00001"),
            VariableDefinition(name: "week", sampleValue: "28")
        ]
    ) {
        self.labelSize = labelSize
        self.elements = elements
        self.printSettings = printSettings
        self.variables = variables
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self = try JSONDecoder().decode(ZPrintDocument.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(self)
        return FileWrapper(regularFileWithContents: data)
    }
}
