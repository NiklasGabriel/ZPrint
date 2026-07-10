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
    var runningVariableID: UUID?
    var variableRanges: [PrintVariableRange]
    var printVariableValues: [UUID: String]

    init(
        counterStart: Int = 1,
        counterEnd: Int = 1,
        numberFormat: String = "00000",
        copiesPerNumber: Int = 1,
        selectedPrinterName: String? = nil,
        runningVariableID: UUID? = nil,
        variableRanges: [PrintVariableRange] = [],
        printVariableValues: [UUID: String] = [:]
    ) {
        self.counterStart = max(1, counterStart)
        self.counterEnd = max(1, counterEnd)
        self.numberFormat = numberFormat
        self.copiesPerNumber = max(1, copiesPerNumber)
        self.selectedPrinterName = selectedPrinterName
        self.runningVariableID = runningVariableID
        self.variableRanges = variableRanges.map(\.clamped)
        self.printVariableValues = printVariableValues
    }

    static let standard = PrintSettings()

    private enum CodingKeys: String, CodingKey {
        case counterStart
        case counterEnd
        case numberFormat
        case copiesPerNumber
        case selectedPrinterName
        case runningVariableID
        case variableRanges
        case printVariableValues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        counterStart = max(1, container.decodeOrDefault(Int.self, forKey: .counterStart, default: 1))
        counterEnd = max(1, container.decodeOrDefault(Int.self, forKey: .counterEnd, default: 1))
        numberFormat = container.decodeOrDefault(String.self, forKey: .numberFormat, default: "00000")
        copiesPerNumber = max(1, container.decodeOrDefault(Int.self, forKey: .copiesPerNumber, default: 1))
        selectedPrinterName = try? container.decodeIfPresent(String.self, forKey: .selectedPrinterName)
        runningVariableID = try? container.decodeIfPresent(UUID.self, forKey: .runningVariableID)
        variableRanges = container.decodeLossyArray([PrintVariableRange].self, forKey: .variableRanges)
        variableRanges = variableRanges.map(\.clamped)
        printVariableValues = container.decodeOrDefault([UUID: String].self, forKey: .printVariableValues, default: [:])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(counterStart, forKey: .counterStart)
        try container.encode(counterEnd, forKey: .counterEnd)
        try container.encode(numberFormat, forKey: .numberFormat)
        try container.encode(copiesPerNumber, forKey: .copiesPerNumber)
        try container.encodeIfPresent(selectedPrinterName, forKey: .selectedPrinterName)
        try container.encodeIfPresent(runningVariableID, forKey: .runningVariableID)
        try container.encode(variableRanges.map(\.clamped), forKey: .variableRanges)
        try container.encode(printVariableValues, forKey: .printVariableValues)
    }

    func range(for variable: VariableDefinition) -> PrintVariableRange? {
        variableRanges.first { $0.variableID == variable.id }
    }

    func runningVariable(in variables: [VariableDefinition]) -> VariableDefinition? {
        if let runningVariableID,
           let variable = variables.first(where: { $0.id == runningVariableID }) {
            return variable
        }

        return variables.first { $0.type == .sequence } ?? variables.first
    }

    func runningRange(for variables: [VariableDefinition]) -> PrintVariableRange? {
        guard let runningVariable = runningVariable(in: variables) else {
            return nil
        }

        return range(for: runningVariable)
            ?? PrintVariableRange(
                variableID: runningVariable.id,
                variableName: runningVariable.name,
                startValue: counterStart,
                endValue: max(counterStart, counterEnd),
                copiesPerValue: copiesPerNumber
            )
    }

    func normalized(for variables: [VariableDefinition]) -> PrintSettings {
        let sequenceVariables = variables.filter { $0.type == .sequence }
        let validRunningVariableID: UUID?

        if let runningVariableID,
           variables.contains(where: { $0.id == runningVariableID && ($0.type == .sequence || sequenceVariables.isEmpty) }) {
            validRunningVariableID = runningVariableID
        } else {
            validRunningVariableID = sequenceVariables.first?.id ?? variables.first?.id
        }

        var normalizedRanges: [PrintVariableRange] = []
        let validVariableIDs = Set(variables.map(\.id))
        var normalizedPrintVariableValues = printVariableValues.filter { key, _ in
            validVariableIDs.contains(key)
        }

        for variable in sequenceVariables {
            var range = variableRanges.first { $0.variableID == variable.id }
                ?? PrintVariableRange(
                    variableID: variable.id,
                    variableName: variable.name,
                    startValue: variable.id == validRunningVariableID ? counterStart : variable.startValue,
                    endValue: variable.id == validRunningVariableID ? max(counterStart, counterEnd) : max(variable.startValue, variable.endValue),
                    copiesPerValue: variable.id == validRunningVariableID ? copiesPerNumber : 1
                )
            range.variableName = variable.name
            normalizedRanges.append(range.clamped)
        }

        for variable in variables where variable.id != validRunningVariableID {
            if normalizedPrintVariableValues[variable.id] == nil {
                normalizedPrintVariableValues[variable.id] = variable.defaultValue
            }
        }

        return PrintSettings(
            counterStart: counterStart,
            counterEnd: counterEnd,
            numberFormat: numberFormat,
            copiesPerNumber: copiesPerNumber,
            selectedPrinterName: selectedPrinterName,
            runningVariableID: validRunningVariableID,
            variableRanges: normalizedRanges,
            printVariableValues: normalizedPrintVariableValues
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
