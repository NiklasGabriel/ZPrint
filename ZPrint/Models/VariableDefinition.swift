//
//  VariableDefinition.swift
//  ZPrint
//

import Foundation

struct VariableDefinition: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var type: VariableType
    var defaultValue: String
    var format: String
    var prefix: String
    var startValue: Int
    var endValue: Int
    var step: Int

    init(
        id: UUID = UUID(),
        name: String,
        type: VariableType = .text,
        defaultValue: String = "",
        format: String = "",
        prefix: String = "",
        startValue: Int = 1,
        endValue: Int = 1,
        step: Int = 1
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.format = format
        self.prefix = prefix
        self.startValue = startValue
        self.endValue = endValue
        self.step = step
    }

    static let standardVariables: [VariableDefinition] = [
        VariableDefinition(
            name: "number",
            type: .sequence,
            format: "00000",
            startValue: 1,
            endValue: 1,
            step: 1
        ),
        VariableDefinition(name: "name"),
        VariableDefinition(name: "week"),
        VariableDefinition(name: "amount"),
        VariableDefinition(name: "id")
    ]

    var placeholder: String {
        let placeholderName = name.isEmpty ? "variable" : name

        if type == .sequence && !format.isEmpty {
            return "{{\(placeholderName):\(format)}}"
        }

        return "{{\(placeholderName)}}"
    }

    var chipTitle: String {
        let titleName = name.isEmpty ? "variable" : name

        if type == .sequence {
            let numberPattern = format.isEmpty ? "#" : format
            let displayPattern = "\(prefix)\(numberPattern)"
            return "\(titleName) · \(displayPattern)"
        }

        return titleName
    }

    var isProtectedStandardVariable: Bool {
        ["number", "name", "week", "amount", "id"].contains(name)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case defaultValue
        case format
        case prefix
        case startValue
        case endValue
        case step
        case key
        case displayName
        case valueType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = container.decodeOrDefault(UUID.self, forKey: .id, default: UUID())
        name = (try? container.decodeIfPresent(String.self, forKey: .name))
            ?? (try? container.decodeIfPresent(String.self, forKey: .key))
            ?? (try? container.decodeIfPresent(String.self, forKey: .displayName))
            ?? "variable"
        type = (try? container.decodeIfPresent(VariableType.self, forKey: .type))
            ?? VariableType(legacyValueType: (try? container.decodeIfPresent(LegacyVariableValueType.self, forKey: .valueType)) ?? nil)
        defaultValue = container.decodeOrDefault(String.self, forKey: .defaultValue, default: "")
        format = container.decodeOrDefault(String.self, forKey: .format, default: "")
        prefix = container.decodeOrDefault(String.self, forKey: .prefix, default: "")
        startValue = max(1, container.decodeOrDefault(Int.self, forKey: .startValue, default: 1))
        endValue = max(1, container.decodeOrDefault(Int.self, forKey: .endValue, default: 1))
        step = max(1, container.decodeOrDefault(Int.self, forKey: .step, default: 1))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(defaultValue, forKey: .defaultValue)
        try container.encode(format, forKey: .format)
        try container.encode(prefix, forKey: .prefix)
        try container.encode(startValue, forKey: .startValue)
        try container.encode(endValue, forKey: .endValue)
        try container.encode(step, forKey: .step)
    }
}

enum VariableType: String, Codable, CaseIterable, Equatable, Sendable {
    case text
    case sequence

    var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .sequence:
            return "Sequenz"
        }
    }

    fileprivate init(legacyValueType: LegacyVariableValueType?) {
        switch legacyValueType {
        case .number:
            self = .sequence
        case .date, .text, .none:
            self = .text
        }
    }
}

private enum LegacyVariableValueType: String, Codable {
    case text
    case number
    case date
}
