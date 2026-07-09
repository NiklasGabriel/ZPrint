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

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder.zprint.encode(self)
        return FileWrapper(regularFileWithContents: data)
    }

    static func standardNewDocument() -> ZPrintDocument {
        let labelSize = LabelSize.standard51x25mm300dpi

        return ZPrintDocument(
            documentName: "Untitled Label",
            labelSizeId: labelSize.id,
            label: labelSize,
            elements: [],
            variables: [],
            guides: [],
            printSettings: .standard,
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
