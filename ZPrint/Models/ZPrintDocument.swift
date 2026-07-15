//
//  ZPrintDocument.swift
//  ZPrint
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ZPrintDocument: FileDocument, Codable, Equatable, Sendable {
    static var readableContentTypes: [UTType] { [.zprint] }
    static var writableContentTypes: [UTType] { [.zprint] }

    var fileVersion: Int
    var documentName: String
    var labelSizeId: String
    var label: LabelSize
    var elements: [LabelElement]
    var variables: [VariableDefinition]
    var tableSources: [TableDataSource]
    var guides: [GuideElement]
    var printSettings: PrintSettings
    var viewSettings: ViewSettings

    init(
        fileVersion: Int = 1,
        documentName: String,
        labelSizeId: String,
        label: LabelSize,
        elements: [LabelElement] = [],
        variables: [VariableDefinition] = [],
        tableSources: [TableDataSource] = [],
        guides: [GuideElement] = [],
        printSettings: PrintSettings = .standard,
        viewSettings: ViewSettings = .standard
    ) {
        self.fileVersion = fileVersion
        self.documentName = documentName
        self.labelSizeId = labelSizeId
        self.label = label
        self.elements = elements
        self.variables = variables
        self.tableSources = tableSources
        self.guides = guides
        self.printSettings = printSettings
        self.viewSettings = viewSettings
    }

    init() {
        self = .standardNewDocument()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw ZPrintDocumentError.missingFileData
        }

        self = try JSONDecoder.zprint.decode(ZPrintDocument.self, from: data)
    }

    private enum CodingKeys: String, CodingKey {
        case fileVersion
        case documentName
        case labelSizeId
        case label
        case elements
        case variables
        case tableSources
        case guides
        case printSettings
        case viewSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let standardDocument = Self.standardNewDocument()

        fileVersion = container.decodeOrDefault(Int.self, forKey: .fileVersion, default: standardDocument.fileVersion)
        documentName = container.decodeOrDefault(String.self, forKey: .documentName, default: standardDocument.documentName)

        let decodedLabelSizeId = container.decodeOrDefault(
            String.self,
            forKey: .labelSizeId,
            default: standardDocument.labelSizeId
        )
        let decodedLabel = (try? container.decodeIfPresent(LabelSize.self, forKey: .label))
            ?? LabelSize.standardSizes.first { $0.id == decodedLabelSizeId }
            ?? standardDocument.label

        label = decodedLabel
        labelSizeId = decodedLabel.id
        elements = container.decodeLossyArray([LabelElement].self, forKey: .elements)
            .map { $0.replacingFrame($0.frame.clamped(to: decodedLabel)) }
        variables = container.decodeLossyArray([VariableDefinition].self, forKey: .variables)
        tableSources = container.decodeLossyArray([TableDataSource].self, forKey: .tableSources)
        guides = container.decodeLossyArray([GuideElement].self, forKey: .guides)
            .map { $0.clamped(to: decodedLabel) }
        printSettings = container.decodeOrDefault(PrintSettings.self, forKey: .printSettings, default: standardDocument.printSettings)
            .normalized(for: variables)
        viewSettings = container.decodeOrDefault(ViewSettings.self, forKey: .viewSettings, default: standardDocument.viewSettings)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder.zprint.encode(self)
        return FileWrapper(regularFileWithContents: data)
    }

    static func standardNewDocument() -> ZPrintDocument {
        let labelSize = LabelSize.standard51x25mm300dpi
        let variables: [VariableDefinition] = []
        let printSettings = PrintSettings.standard.normalized(for: variables)

        return ZPrintDocument(
            documentName: "Untitled Label",
            labelSizeId: labelSize.id,
            label: labelSize,
            elements: [],
            variables: variables,
            guides: [],
            printSettings: printSettings,
            viewSettings: .standard
        )
    }
}

enum ZPrintDocumentError: Error, LocalizedError {
    case missingFileData

    var errorDescription: String? {
        switch self {
        case .missingFileData:
            return "The selected ZPrint document does not contain readable file data."
        }
    }
}
