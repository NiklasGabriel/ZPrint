import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let zprint = UTType(exportedAs: "com.niklasgabriel.zprint", conformingTo: .json)
}

struct ZPrintDocument: FileDocument, Codable {
    static let currentFileVersion = 1
    static var readableContentTypes: [UTType] { [.zprint] }
    static var writableContentTypes: [UTType] { [.zprint] }

    var fileVersion: Int
    var documentName: String
    var labelSizeId: String
    var label: Label
    var elements: [LabelElement]
    var variables: [VariableDefinition]
    var printSettings: PrintSettings

    var labelSize: LabelSize {
        get {
            LabelSize(
                id: labelSizeId,
                name: LabelSize.displayName(for: labelSizeId),
                widthDots: label.widthDots,
                heightDots: label.heightDots,
                dpi: label.dpi
            )
        }
        set {
            labelSizeId = newValue.id
            label = Label(size: newValue)
        }
    }

    init(
        fileVersion: Int = ZPrintDocument.currentFileVersion,
        documentName: String = "Untitled Label",
        labelSize: LabelSize = .label51x25mm,
        elements: [LabelElement] = [
            .text(TextLabelElement(xDots: 40, yDots: 40, text: "{{name}}")),
            .barcode(BarcodeLabelElement(xDots: 40, yDots: 110, value: "{{number:00000}}"))
        ],
        variables: [VariableDefinition] = [
            VariableDefinition(name: "name", sampleValue: "Demo"),
            VariableDefinition(name: "number", sampleValue: "00001"),
            VariableDefinition(name: "week", sampleValue: "28")
        ],
        printSettings: PrintSettings = PrintSettings()
    ) {
        self.fileVersion = fileVersion
        self.documentName = documentName
        self.labelSizeId = labelSize.id
        self.label = Label(size: labelSize)
        self.elements = elements
        self.variables = variables
        self.printSettings = printSettings
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let decoder = JSONDecoder()
        self = try decoder.decode(ZPrintDocument.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return FileWrapper(regularFileWithContents: data)
    }
}
