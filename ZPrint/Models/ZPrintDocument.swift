import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let zprint = UTType(filenameExtension: "zprint", conformingTo: .json)
        ?? UTType(exportedAs: "com.niklasgabriel.zprint", conformingTo: .json)
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
    var variables: [String: String]
    var printSettings: PrintSettings

    var labelSize: LabelSize {
        get {
            LabelSize(
                id: label.id,
                name: label.name,
                widthMm: label.widthMm,
                heightMm: label.heightMm,
                dpi: label.dpi,
                widthDots: label.widthDots,
                heightDots: label.heightDots
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
        elements: [LabelElement] = [],
        variables: [String: String] = [:],
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
        guard let data = configuration.file.regularFileContents, !data.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let decoder = JSONDecoder()
        do {
            self = try decoder.decode(ZPrintDocument.self, from: data)
            try validateAfterRead()
            normalizeForEditing()
        } catch let decodingError as DecodingError {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSUnderlyingErrorKey: decodingError])
        } catch {
            throw error
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let snapshot = normalizedForWriting()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(snapshot)
        return FileWrapper(regularFileWithContents: data)
    }

    private mutating func normalizeForEditing() {
        if documentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            documentName = "Untitled Label"
        }

        if label.id.isEmpty {
            label = Label(size: .label51x25mm)
        }

        labelSizeId = label.id

        if printSettings.copiesPerNumber < 1 {
            printSettings.copiesPerNumber = 1
        }
    }

    private func normalizedForWriting() -> ZPrintDocument {
        var snapshot = self
        snapshot.fileVersion = Self.currentFileVersion
        snapshot.normalizeForEditing()
        return snapshot
    }

    private func validateAfterRead() throws {
        guard fileVersion == Self.currentFileVersion else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }

        guard !label.id.isEmpty,
              !label.name.isEmpty,
              label.widthMm > 0,
              label.heightMm > 0,
              label.widthDots > 0,
              label.heightDots > 0,
              label.dpi > 0
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
}
