//
//  TableDataSource.swift
//  ZPrint
//

import Foundation

struct TableDataSource: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var fileName: String
    var sourcePath: String
    var securityScopedBookmark: Data?
    var importedAt: String
    var sourceModifiedAt: String?
    var sheets: [TableSheetSnapshot]

    init(
        id: UUID = UUID(),
        fileName: String,
        sourcePath: String,
        securityScopedBookmark: Data?,
        importedAt: String,
        sourceModifiedAt: String?,
        sheets: [TableSheetSnapshot]
    ) {
        self.id = id
        self.fileName = fileName
        self.sourcePath = sourcePath
        self.securityScopedBookmark = securityScopedBookmark
        self.importedAt = importedAt
        self.sourceModifiedAt = sourceModifiedAt
        self.sheets = sheets
    }

    var displayName: String {
        fileName.isEmpty ? "Tabelle" : fileName
    }

    var totalRowCount: Int {
        sheets.reduce(0) { $0 + $1.rows.count }
    }

    func sheet(named name: String) -> TableSheetSnapshot? {
        sheets.first { $0.name == name }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fileName
        case sourcePath
        case securityScopedBookmark
        case importedAt
        case sourceModifiedAt
        case sheets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = container.decodeOrDefault(UUID.self, forKey: .id, default: UUID())
        fileName = container.decodeOrDefault(String.self, forKey: .fileName, default: "Tabelle")
        sourcePath = container.decodeOrDefault(String.self, forKey: .sourcePath, default: "")
        securityScopedBookmark = try? container.decodeIfPresent(Data.self, forKey: .securityScopedBookmark)
        importedAt = container.decodeOrDefault(String.self, forKey: .importedAt, default: "")
        sourceModifiedAt = try? container.decodeIfPresent(String.self, forKey: .sourceModifiedAt)
        sheets = container.decodeLossyArray([TableSheetSnapshot].self, forKey: .sheets)
    }
}

struct TableSheetSnapshot: Codable, Equatable, Identifiable, Sendable {
    var name: String
    var headers: [String]
    var rows: [[String]]

    var id: String { name }

    func value(
        matching lookupValue: String,
        keyColumn: String,
        valueColumn: String,
        caseSensitive: Bool
    ) -> String? {
        guard let keyIndex = headers.firstIndex(of: keyColumn),
              let valueIndex = headers.firstIndex(of: valueColumn) else {
            return nil
        }

        let normalizedLookupValue = Self.normalized(lookupValue, caseSensitive: caseSensitive)
        guard !normalizedLookupValue.isEmpty else {
            return nil
        }

        for row in rows where keyIndex < row.count {
            let candidate = Self.normalized(row[keyIndex], caseSensitive: caseSensitive)
            if candidate == normalizedLookupValue {
                return valueIndex < row.count ? row[valueIndex] : ""
            }
        }

        return nil
    }

    func duplicateKeyCount(in column: String, caseSensitive: Bool) -> Int {
        guard let index = headers.firstIndex(of: column) else {
            return 0
        }

        var seen = Set<String>()
        var duplicateCount = 0
        for row in rows where index < row.count {
            let value = Self.normalized(row[index], caseSensitive: caseSensitive)
            guard !value.isEmpty else {
                continue
            }

            if !seen.insert(value).inserted {
                duplicateCount += 1
            }
        }
        return duplicateCount
    }

    private static func normalized(_ value: String, caseSensitive: Bool) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return caseSensitive ? trimmed : trimmed.folding(options: [.caseInsensitive], locale: .current)
    }
}
