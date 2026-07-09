//
//  PrintSettings.swift
//  ZPrint
//

import Foundation

struct PrintSettings: Codable, Equatable, Sendable {
    var counterStart: Int
    var counterEnd: Int
    var variableRanges: [PrintVariableRange]

    init(
        counterStart: Int = 1,
        counterEnd: Int = 1,
        variableRanges: [PrintVariableRange] = []
    ) {
        self.counterStart = max(1, counterStart)
        self.counterEnd = max(1, counterEnd)
        self.variableRanges = variableRanges.map(\.clamped)
    }

    static let standard = PrintSettings()

    private enum CodingKeys: String, CodingKey {
        case counterStart
        case counterEnd
        case variableRanges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        counterStart = max(1, try container.decodeIfPresent(Int.self, forKey: .counterStart) ?? 1)
        counterEnd = max(1, try container.decodeIfPresent(Int.self, forKey: .counterEnd) ?? 1)
        variableRanges = try container.decodeIfPresent([PrintVariableRange].self, forKey: .variableRanges) ?? []
        variableRanges = variableRanges.map(\.clamped)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(counterStart, forKey: .counterStart)
        try container.encode(counterEnd, forKey: .counterEnd)
        try container.encode(variableRanges.map(\.clamped), forKey: .variableRanges)
    }

    func range(for variable: VariableDefinition) -> PrintVariableRange? {
        variableRanges.first { $0.variableID == variable.id }
    }

    func normalized(for variables: [VariableDefinition]) -> PrintSettings {
        let sequenceVariables = variables.filter { $0.type == .sequence }
        var normalizedRanges: [PrintVariableRange] = []

        for variable in sequenceVariables {
            var range = variableRanges.first { $0.variableID == variable.id }
                ?? PrintVariableRange(
                    variableID: variable.id,
                    variableName: variable.name,
                    startValue: variable.startValue,
                    endValue: max(variable.startValue, variable.endValue),
                    copiesPerValue: 1
                )
            range.variableName = variable.name
            normalizedRanges.append(range.clamped)
        }

        return PrintSettings(
            counterStart: counterStart,
            counterEnd: counterEnd,
            variableRanges: normalizedRanges
        )
    }
}

struct PrintVariableRange: Codable, Equatable, Identifiable, Sendable {
    var variableID: UUID
    var variableName: String
    var startValue: Int
    var endValue: Int
    var copiesPerValue: Int

    var id: UUID { variableID }

    init(
        variableID: UUID,
        variableName: String,
        startValue: Int = 1,
        endValue: Int = 1,
        copiesPerValue: Int = 1
    ) {
        self.variableID = variableID
        self.variableName = variableName
        self.startValue = startValue
        self.endValue = endValue
        self.copiesPerValue = copiesPerValue
    }

    var clamped: PrintVariableRange {
        var range = self
        range.startValue = max(1, range.startValue)
        range.endValue = max(range.startValue, range.endValue)
        range.copiesPerValue = max(1, range.copiesPerValue)
        return range
    }

    func estimatedLabelCount(step: Int) -> Int {
        let clampedStep = max(1, step)
        let valueCount = max(1, ((endValue - startValue) / clampedStep) + 1)
        return valueCount * max(1, copiesPerValue)
    }
}
