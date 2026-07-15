//
//  TableDataImporter.swift
//  ZPrint
//

import Foundation
import UniformTypeIdentifiers
import zlib

enum TableDataImporter {
    static let allowedContentTypes: [UTType] = [
        UTType(filenameExtension: "xlsx") ?? .spreadsheet,
        .commaSeparatedText,
        .tabSeparatedText
    ]

    static func load(from url: URL, preservingID id: UUID = UUID()) throws -> TableDataSource {
        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let sheets: [TableSheetSnapshot]

        switch url.pathExtension.lowercased() {
        case "xlsx":
            sheets = try XLSXTableReader.readSheets(from: data)
        case "csv":
            sheets = [try DelimitedTableReader.readSheet(from: data, name: url.deletingPathExtension().lastPathComponent, preferredDelimiter: nil)]
        case "tsv":
            sheets = [try DelimitedTableReader.readSheet(from: data, name: url.deletingPathExtension().lastPathComponent, preferredDelimiter: "\t")]
        default:
            throw TableDataImportError.unsupportedFormat
        }

        guard sheets.contains(where: { !$0.headers.isEmpty }) else {
            throw TableDataImportError.noReadableRows
        }

        let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let modificationDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        return TableDataSource(
            id: id,
            fileName: url.lastPathComponent,
            sourcePath: url.path,
            securityScopedBookmark: bookmark,
            importedAt: timestamp(Date()),
            sourceModifiedAt: modificationDate.map(timestamp),
            sheets: sheets
        )
    }

    static func refresh(_ source: TableDataSource, onlyIfChanged: Bool = false) throws -> TableDataSource {
        let url = try sourceURL(for: source)

        if onlyIfChanged,
           let sourceModifiedAt = source.sourceModifiedAt,
           let modificationDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           timestamp(modificationDate) == sourceModifiedAt {
            return source
        }

        return try load(from: url, preservingID: source.id)
    }

    private static func sourceURL(for source: TableDataSource) throws -> URL {
        if let bookmark = source.securityScopedBookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return url
            }
        }

        guard !source.sourcePath.isEmpty,
              FileManager.default.fileExists(atPath: source.sourcePath) else {
            throw TableDataImportError.sourceUnavailable
        }

        return URL(fileURLWithPath: source.sourcePath)
    }

    private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

enum TableDataImportError: Error, LocalizedError {
    case unsupportedFormat
    case invalidWorkbook
    case unsupportedWorkbookArchive
    case noReadableRows
    case sourceUnavailable
    case archiveTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unterstützt werden Excel-.xlsx-, CSV- und TSV-Dateien."
        case .invalidWorkbook:
            return "Die Excel-Datei ist beschädigt oder enthält keine lesbaren Tabellenblätter."
        case .unsupportedWorkbookArchive:
            return "Diese Excel-Datei verwendet eine nicht unterstützte ZIP-Variante."
        case .noReadableRows:
            return "Die Tabelle enthält keine lesbare Kopfzeile und keine Datenzeilen."
        case .sourceUnavailable:
            return "Die verknüpfte Quelldatei ist nicht mehr erreichbar. Bitte wähle sie erneut aus."
        case .archiveTooLarge:
            return "Die Excel-Datei ist für den sicheren Import zu groß."
        }
    }
}

private enum DelimitedTableReader {
    static func readSheet(
        from data: Data,
        name: String,
        preferredDelimiter: Character?
    ) throws -> TableSheetSnapshot {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw TableDataImportError.noReadableRows
        }

        let delimiter = preferredDelimiter ?? detectedDelimiter(in: text)
        let rawRows = parse(text, delimiter: delimiter)
        return try TableSnapshotBuilder.makeSheet(name: name, rows: rawRows)
    }

    private static func detectedDelimiter(in text: String) -> Character {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let semicolons = firstLine.filter { $0 == ";" }.count
        let tabs = firstLine.filter { $0 == "\t" }.count
        let commas = firstLine.filter { $0 == "," }.count

        if tabs > max(semicolons, commas) {
            return "\t"
        }
        return semicolons > commas ? ";" : ","
    }

    private static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "\"" {
                let nextIndex = text.index(after: index)
                if isInsideQuotes, nextIndex < text.endIndex, text[nextIndex] == "\"" {
                    field.append("\"")
                    index = nextIndex
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == delimiter, !isInsideQuotes {
                row.append(field)
                field = ""
            } else if character.isNewline, !isInsideQuotes {
                if character == "\r" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                        index = nextIndex
                    }
                }
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }

            index = text.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }
}

private enum XLSXTableReader {
    static func readSheets(from data: Data) throws -> [TableSheetSnapshot] {
        let archive = try ZIPArchive(data: data)
        guard let workbookData = try archive.data(for: "xl/workbook.xml"),
              let relationshipsData = try archive.data(for: "xl/_rels/workbook.xml.rels") else {
            throw TableDataImportError.invalidWorkbook
        }

        let workbookSheets = try WorkbookSheetParser.parse(workbookData)
        let relationships = try WorkbookRelationshipParser.parse(relationshipsData)
        let sharedStrings: [String]

        if let sharedStringsData = try archive.data(for: "xl/sharedStrings.xml") {
            sharedStrings = try SharedStringsParser.parse(sharedStringsData)
        } else {
            sharedStrings = []
        }

        var sheets: [TableSheetSnapshot] = []
        for workbookSheet in workbookSheets {
            guard let target = relationships[workbookSheet.relationshipID] else {
                continue
            }

            let path = normalizedWorksheetPath(target)
            guard let worksheetData = try archive.data(for: path) else {
                continue
            }

            let rows = try WorksheetParser.parse(worksheetData, sharedStrings: sharedStrings)
            if let sheet = try? TableSnapshotBuilder.makeSheet(name: workbookSheet.name, rows: rows) {
                sheets.append(sheet)
            }
        }

        guard !sheets.isEmpty else {
            throw TableDataImportError.invalidWorkbook
        }
        return sheets
    }

    private static func normalizedWorksheetPath(_ target: String) -> String {
        let candidate = target.hasPrefix("/")
            ? String(target.dropFirst())
            : "xl/\(target)"
        var components: [String] = []

        for component in candidate.split(separator: "/").map(String.init) {
            if component == ".." {
                _ = components.popLast()
            } else if component != "." {
                components.append(component)
            }
        }

        return components.joined(separator: "/")
    }
}

private enum TableSnapshotBuilder {
    static func makeSheet(name: String, rows: [[String]]) throws -> TableSheetSnapshot {
        guard let headerIndex = rows.firstIndex(where: { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }) else {
            throw TableDataImportError.noReadableRows
        }

        let maximumColumnCount = rows[headerIndex...].map(\.count).max() ?? 0
        guard maximumColumnCount > 0 else {
            throw TableDataImportError.noReadableRows
        }

        var usedHeaders: [String: Int] = [:]
        let rawHeaders = padded(rows[headerIndex], to: maximumColumnCount)
        let headers = rawHeaders.enumerated().map { index, rawHeader in
            let trimmed = rawHeader.trimmingCharacters(in: .whitespacesAndNewlines)
            let base = trimmed.isEmpty ? "Spalte \(columnName(index))" : trimmed
            let occurrence = (usedHeaders[base] ?? 0) + 1
            usedHeaders[base] = occurrence
            return occurrence == 1 ? base : "\(base) (\(occurrence))"
        }

        let dataRows = rows.dropFirst(headerIndex + 1)
            .map { padded($0, to: maximumColumnCount) }
            .filter { row in
                row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }

        return TableSheetSnapshot(name: name.isEmpty ? "Tabelle 1" : name, headers: headers, rows: dataRows)
    }

    private static func padded(_ row: [String], to count: Int) -> [String] {
        if row.count >= count {
            return Array(row.prefix(count))
        }
        return row + Array(repeating: "", count: count - row.count)
    }

    private static func columnName(_ zeroBasedIndex: Int) -> String {
        var index = zeroBasedIndex + 1
        var result = ""
        while index > 0 {
            let remainder = (index - 1) % 26
            result.insert(Character(UnicodeScalar(65 + remainder)!), at: result.startIndex)
            index = (index - 1) / 26
        }
        return result
    }
}

private struct ZIPArchive {
    private struct Entry {
        let compressionMethod: Int
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private let data: Data
    private let entries: [String: Entry]
    private let maximumEntrySize = 100 * 1024 * 1024

    init(data: Data) throws {
        self.data = data
        entries = try Self.readEntries(from: data)
    }

    func data(for path: String) throws -> Data? {
        guard let entry = entries[path] else {
            return nil
        }
        guard entry.uncompressedSize <= maximumEntrySize else {
            throw TableDataImportError.archiveTooLarge
        }

        let offset = entry.localHeaderOffset
        guard data.uint32LE(at: offset) == 0x04034B50 else {
            throw TableDataImportError.invalidWorkbook
        }

        let fileNameLength = data.uint16LE(at: offset + 26)
        let extraLength = data.uint16LE(at: offset + 28)
        let payloadOffset = offset + 30 + fileNameLength + extraLength
        guard payloadOffset >= 0,
              entry.compressedSize >= 0,
              payloadOffset + entry.compressedSize <= data.count else {
            throw TableDataImportError.invalidWorkbook
        }

        let compressedData = data.subdata(in: payloadOffset..<(payloadOffset + entry.compressedSize))
        switch entry.compressionMethod {
        case 0:
            return compressedData
        case 8:
            return try Self.inflate(compressedData, expectedSize: entry.uncompressedSize)
        default:
            throw TableDataImportError.unsupportedWorkbookArchive
        }
    }

    private static func readEntries(from data: Data) throws -> [String: Entry] {
        guard let endOffset = endOfCentralDirectoryOffset(in: data) else {
            throw TableDataImportError.invalidWorkbook
        }

        let entryCount = data.uint16LE(at: endOffset + 10)
        let centralDirectoryOffset = data.uint32LE(at: endOffset + 16)
        guard entryCount <= 20_000,
              centralDirectoryOffset >= 0,
              centralDirectoryOffset < data.count else {
            throw TableDataImportError.unsupportedWorkbookArchive
        }

        var entries: [String: Entry] = [:]
        var offset = centralDirectoryOffset

        for _ in 0..<entryCount {
            guard data.uint32LE(at: offset) == 0x02014B50 else {
                throw TableDataImportError.invalidWorkbook
            }

            let compressionMethod = data.uint16LE(at: offset + 10)
            let compressedSize = data.uint32LE(at: offset + 20)
            let uncompressedSize = data.uint32LE(at: offset + 24)
            let fileNameLength = data.uint16LE(at: offset + 28)
            let extraLength = data.uint16LE(at: offset + 30)
            let commentLength = data.uint16LE(at: offset + 32)
            let localHeaderOffset = data.uint32LE(at: offset + 42)
            let nameStart = offset + 46
            let nameEnd = nameStart + fileNameLength

            guard nameEnd <= data.count else {
                throw TableDataImportError.invalidWorkbook
            }

            let nameData = data.subdata(in: nameStart..<nameEnd)
            guard let name = String(data: nameData, encoding: .utf8) else {
                throw TableDataImportError.invalidWorkbook
            }

            entries[name] = Entry(
                compressionMethod: compressionMethod,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            )
            offset = nameEnd + extraLength + commentLength
        }

        return entries
    }

    private static func endOfCentralDirectoryOffset(in data: Data) -> Int? {
        guard data.count >= 22 else {
            return nil
        }

        let minimumOffset = max(0, data.count - 65_557)
        for offset in stride(from: data.count - 22, through: minimumOffset, by: -1) {
            if data.uint32LE(at: offset) == 0x06054B50 {
                return offset
            }
        }
        return nil
    }

    private static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        guard expectedSize >= 0 else {
            throw TableDataImportError.invalidWorkbook
        }
        if expectedSize == 0 {
            return Data()
        }

        var stream = z_stream()
        guard inflateInit2_(
            &stream,
            -MAX_WBITS,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        ) == Z_OK else {
            throw TableDataImportError.invalidWorkbook
        }
        defer { inflateEnd(&stream) }

        var output = [UInt8](repeating: 0, count: expectedSize)
        let status = output.withUnsafeMutableBytes { outputBuffer in
            data.withUnsafeBytes { inputBuffer in
                stream.next_in = UnsafeMutablePointer<Bytef>(
                    mutating: inputBuffer.bindMemory(to: Bytef.self).baseAddress!
                )
                stream.avail_in = uInt(data.count)
                stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress!
                stream.avail_out = uInt(expectedSize)
                return zlib.inflate(&stream, Z_FINISH)
            }
        }

        guard status == Z_STREAM_END,
              stream.total_out == expectedSize else {
            throw TableDataImportError.invalidWorkbook
        }
        return Data(output)
    }
}

private extension Data {
    func uint16LE(at offset: Int) -> Int {
        guard offset >= 0, offset + 2 <= count else {
            return -1
        }
        return Int(self[index(startIndex, offsetBy: offset)])
            | (Int(self[index(startIndex, offsetBy: offset + 1)]) << 8)
    }

    func uint32LE(at offset: Int) -> Int {
        guard offset >= 0, offset + 4 <= count else {
            return -1
        }
        return Int(self[index(startIndex, offsetBy: offset)])
            | (Int(self[index(startIndex, offsetBy: offset + 1)]) << 8)
            | (Int(self[index(startIndex, offsetBy: offset + 2)]) << 16)
            | (Int(self[index(startIndex, offsetBy: offset + 3)]) << 24)
    }
}

private struct WorkbookSheet {
    let name: String
    let relationshipID: String
}

private func xmlLocalName(_ name: String) -> Substring {
    name.split(separator: ":", omittingEmptySubsequences: false).last ?? Substring(name)
}

private final class WorkbookSheetParser: NSObject, XMLParserDelegate {
    private var sheets: [WorkbookSheet] = []

    static func parse(_ data: Data) throws -> [WorkbookSheet] {
        let delegate = WorkbookSheetParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? TableDataImportError.invalidWorkbook
        }
        return delegate.sheets
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard xmlLocalName(elementName) == "sheet",
              let name = attributeDict["name"],
              let relationshipID = attributeDict["r:id"] else {
            return
        }
        sheets.append(WorkbookSheet(name: name, relationshipID: relationshipID))
    }
}

private final class WorkbookRelationshipParser: NSObject, XMLParserDelegate {
    private var relationships: [String: String] = [:]

    static func parse(_ data: Data) throws -> [String: String] {
        let delegate = WorkbookRelationshipParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? TableDataImportError.invalidWorkbook
        }
        return delegate.relationships
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard xmlLocalName(elementName) == "Relationship",
              let id = attributeDict["Id"],
              let target = attributeDict["Target"] else {
            return
        }
        relationships[id] = target
    }
}

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var currentString = ""
    private var currentText = ""
    private var isInsideString = false
    private var isInsideText = false

    static func parse(_ data: Data) throws -> [String] {
        let delegate = SharedStringsParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? TableDataImportError.invalidWorkbook
        }
        return delegate.strings
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = xmlLocalName(elementName)
        if localName == "si" {
            isInsideString = true
            currentString = ""
        } else if localName == "t", isInsideString {
            isInsideText = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideText {
            currentText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = xmlLocalName(elementName)
        if localName == "t", isInsideText {
            currentString += currentText
            isInsideText = false
        } else if localName == "si", isInsideString {
            strings.append(currentString)
            isInsideString = false
        }
    }
}

private final class WorksheetParser: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private var rows: [[String]] = []
    private var currentCells: [Int: String] = [:]
    private var currentCellColumn = 0
    private var currentCellType = ""
    private var currentValue = ""
    private var inlineText = ""
    private var isInsideValue = false
    private var isInsideInlineText = false

    private init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    static func parse(_ data: Data, sharedStrings: [String]) throws -> [[String]] {
        let delegate = WorksheetParser(sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? TableDataImportError.invalidWorkbook
        }
        return delegate.rows
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch xmlLocalName(elementName) {
        case "row":
            currentCells = [:]
        case "c":
            currentCellColumn = Self.columnIndex(from: attributeDict["r"] ?? "")
            currentCellType = attributeDict["t"] ?? ""
            currentValue = ""
            inlineText = ""
        case "v":
            isInsideValue = true
            currentValue = ""
        case "t" where currentCellType == "inlineStr":
            isInsideInlineText = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideValue {
            currentValue += string
        }
        if isInsideInlineText {
            inlineText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch xmlLocalName(elementName) {
        case "v":
            isInsideValue = false
        case "t" where currentCellType == "inlineStr":
            isInsideInlineText = false
        case "c":
            currentCells[currentCellColumn] = resolvedCellValue()
        case "row":
            let maximumColumn = currentCells.keys.max() ?? -1
            if maximumColumn >= 0 {
                rows.append((0...maximumColumn).map { currentCells[$0] ?? "" })
            } else {
                rows.append([])
            }
        default:
            break
        }
    }

    private func resolvedCellValue() -> String {
        switch currentCellType {
        case "s":
            guard let index = Int(currentValue), sharedStrings.indices.contains(index) else {
                return ""
            }
            return sharedStrings[index]
        case "inlineStr":
            return inlineText
        case "b":
            return currentValue == "1" ? "WAHR" : "FALSCH"
        default:
            return currentValue
        }
    }

    private static func columnIndex(from reference: String) -> Int {
        var result = 0
        var foundLetter = false
        for scalar in reference.unicodeScalars {
            let value = Int(scalar.value)
            guard value >= 65, value <= 90 || value >= 97, value <= 122 else {
                break
            }
            let normalized = value >= 97 ? value - 32 : value
            result = result * 26 + (normalized - 64)
            foundLetter = true
        }
        return foundLetter ? max(0, result - 1) : 0
    }
}
