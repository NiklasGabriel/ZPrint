//
//  PrintSettings.swift
//  ZPrint
//

import Foundation

struct PrintSettings: Codable, Equatable, Sendable {
    var counterStart: Int
    var counterEnd: Int
    var numberFormat: String
    var copiesPerNumber: Int
    var selectedPrinterName: String?
    var variableRanges: [PrintVariableRange]

    init(
        counterStart: Int = 1,
        counterEnd: Int = 1,
        numberFormat: String = "00000",
        copiesPerNumber: Int = 1,
        selectedPrinterName: String? = nil,
        variableRanges: [PrintVariableRange] = []
    ) {
        self.counterStart = max(1, counterStart)
        self.counterEnd = max(1, counterEnd)
        self.numberFormat = numberFormat
        self.copiesPerNumber = max(1, copiesPerNumber)
        self.selectedPrinterName = selectedPrinterName
        self.variableRanges = variableRanges.map(\.clamped)
    }

    static let standard = PrintSettings()

    private enum CodingKeys: String, CodingKey {
        case counterStart
        case counterEnd
        case numberFormat
        case copiesPerNumber
        case selectedPrinterName
        case variableRanges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        counterStart = max(1, container.decodeOrDefault(Int.self, forKey: .counterStart, default: 1))
        counterEnd = max(1, container.decodeOrDefault(Int.self, forKey: .counterEnd, default: 1))
        numberFormat = container.decodeOrDefault(String.self, forKey: .numberFormat, default: "00000")
        copiesPerNumber = max(1, container.decodeOrDefault(Int.self, forKey: .copiesPerNumber, default: 1))
        selectedPrinterName = try? container.decodeIfPresent(String.self, forKey: .selectedPrinterName)
        variableRanges = container.decodeLossyArray([PrintVariableRange].self, forKey: .variableRanges)
        variableRanges = variableRanges.map(\.clamped)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(counterStart, forKey: .counterStart)
        try container.encode(counterEnd, forKey: .counterEnd)
        try container.encode(numberFormat, forKey: .numberFormat)
        try container.encode(copiesPerNumber, forKey: .copiesPerNumber)
        try container.encodeIfPresent(selectedPrinterName, forKey: .selectedPrinterName)
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
            numberFormat: numberFormat,
            copiesPerNumber: copiesPerNumber,
            selectedPrinterName: selectedPrinterName,
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

    private enum CodingKeys: String, CodingKey {
        case variableID
        case variableName
        case startValue
        case endValue
        case copiesPerValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        variableID = container.decodeOrDefault(UUID.self, forKey: .variableID, default: UUID())
        variableName = container.decodeOrDefault(String.self, forKey: .variableName, default: "number")
        startValue = max(1, container.decodeOrDefault(Int.self, forKey: .startValue, default: 1))
        endValue = max(startValue, container.decodeOrDefault(Int.self, forKey: .endValue, default: startValue))
        copiesPerValue = max(1, container.decodeOrDefault(Int.self, forKey: .copiesPerValue, default: 1))
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
