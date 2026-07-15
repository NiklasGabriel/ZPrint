//
//  VariableEngine.swift
//  ZPrint
//

import Foundation

struct VariableEngine {
    typealias Context = [String: String]

    var variables: [VariableDefinition]

    init(variables: [VariableDefinition] = []) {
        self.variables = variables
    }

    func renderTemplateString(_ text: String, context: Context = [:]) -> String {
        Self.renderTemplateString(text, context: context, variables: variables)
    }

    static func renderTemplateString(
        _ text: String,
        context: Context = [:],
        variables: [VariableDefinition] = []
    ) -> String {
        let pattern = #"\{\{\s*([A-Za-z0-9_]+)(?::([^}]+))?\s*\}\}"#

        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let nsText = text as NSString
        let matches = expression.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )

        var renderedText = text
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let nameRange = Range(match.range(at: 1), in: text) else {
                continue
            }

            let name = String(text[nameRange])
            let inlineFormat: String?

            if match.numberOfRanges >= 3,
               match.range(at: 2).location != NSNotFound,
               let formatRange = Range(match.range(at: 2), in: text) {
                inlineFormat = String(text[formatRange])
            } else {
                inlineFormat = nil
            }

            let variable = variables.first { $0.name == name }
            let replacement = renderedValue(
                for: name,
                inlineFormat: inlineFormat,
                variable: variable,
                context: context
            )

            if let fullRange = Range(match.range, in: renderedText) {
                renderedText.replaceSubrange(fullRange, with: replacement)
            }
        }

        return renderedText
    }

    static func previewContext(for document: ZPrintDocument) -> Context {
        var context: Context = [:]

        for variable in document.variables {
            if variable.type == .tableLookup {
                continue
            } else if variable.type == .sequence {
                let printRange = document.printSettings.range(for: variable)
                context[variable.name] = "\(printRange?.startValue ?? variable.startValue)"
            } else {
                context[variable.name] = defaultPreviewValue(for: variable.name, document: document)
            }
        }

        return resolvedContext(context, for: document)
    }

    static func normalizedPreviewContext(
        _ context: Context,
        for document: ZPrintDocument
    ) -> Context {
        let defaults = previewContext(for: document)
        var normalized = context.filter { key, _ in
            defaults.keys.contains(key)
        }

        for (key, value) in defaults where normalized[key]?.isEmpty ?? true {
            normalized[key] = value
        }

        return resolvedContext(normalized, for: document)
    }

    static func batchContexts(
        for document: ZPrintDocument,
        limit: Int? = nil
    ) -> [Context] {
        guard let runningVariable = document.printSettings.runningVariable(in: document.variables),
              runningVariable.type == .sequence else {
            return fallbackCounterContexts(for: document, limit: limit)
        }

        var baseContext = Context()
        for variable in document.variables where variable.id != runningVariable.id && variable.type != .tableLookup {
            baseContext[variable.name] = rawPrintValue(for: variable, document: document)
        }

        let values = values(for: runningVariable, document: document, limit: limit)
        guard !values.isEmpty else {
            return []
        }

        return values.map { value in
            var context = baseContext
            context[runningVariable.name] = value
            return resolvedContext(context, for: document)
        }
    }

    static func resolvedContext(_ context: Context, for document: ZPrintDocument) -> Context {
        var resolved = context

        for variable in document.variables where variable.type == .tableLookup {
            guard let lookup = variable.tableLookup,
                  let sourceVariableID = lookup.sourceVariableID,
                  let sourceVariable = document.variables.first(where: { $0.id == sourceVariableID }),
                  let tableSourceID = lookup.tableSourceID,
                  let tableSource = document.tableSources.first(where: { $0.id == tableSourceID }),
                  let sheet = tableSource.sheet(named: lookup.sheetName) else {
                resolved[variable.name] = lookupFallback(for: variable)
                continue
            }

            let rawSourceValue = resolved[sourceVariable.name]
                ?? rawPrintValue(for: sourceVariable, document: document)
            let renderedSourceValue = renderedVariableValue(
                rawSourceValue,
                inlineFormat: nil,
                variable: sourceVariable
            )
            resolved[variable.name] = sheet.value(
                matching: renderedSourceValue,
                keyColumn: lookup.keyColumn,
                valueColumn: lookup.valueColumn,
                caseSensitive: lookup.caseSensitive
            ) ?? lookupFallback(for: variable)
        }

        return resolved
    }

    static func estimatedBatchLabelCount(for document: ZPrintDocument) -> Int {
        guard let runningVariable = document.printSettings.runningVariable(in: document.variables),
              runningVariable.type == .sequence else {
            guard document.printSettings.counterEnd >= document.printSettings.counterStart else {
                return 0
            }

            return ((document.printSettings.counterEnd - document.printSettings.counterStart) + 1)
                * max(1, document.printSettings.copiesPerNumber)
        }

        let range = document.printSettings.range(for: runningVariable)
        let startValue = range?.startValue ?? runningVariable.startValue
        let endValue = range?.endValue ?? max(runningVariable.startValue, runningVariable.endValue)
        let copiesPerValue = max(1, range?.copiesPerValue ?? 1)
        let step = max(1, runningVariable.step)

        guard endValue >= startValue else {
            return 0
        }

        let valueCount = ((endValue - startValue) / step) + 1
        return valueCount * copiesPerValue
    }

    private static func renderedValue(
        for name: String,
        inlineFormat: String?,
        variable: VariableDefinition?,
        context: Context
    ) -> String {
        if let value = context[name], !value.isEmpty {
            return renderedVariableValue(
                value,
                inlineFormat: inlineFormat,
                variable: variable
            )
        }

        if variable?.type == .sequence || inlineFormat != nil {
            return renderedVariableValue(
                "\(variable?.startValue ?? 1)",
                inlineFormat: inlineFormat,
                variable: variable
            )
        }

        switch name {
        case "name":
            return "Name"
        case "week":
            return "\(Calendar.current.component(.weekOfYear, from: Date()))"
        case "amount":
            return "1"
        case "id":
            return "ID"
        default:
            return ""
        }
    }

    private static func fallbackCounterContexts(
        for document: ZPrintDocument,
        limit: Int?
    ) -> [Context] {
        guard document.printSettings.counterEnd >= document.printSettings.counterStart else {
            return []
        }

        let range = document.printSettings.counterStart...document.printSettings.counterEnd
        var contexts: [Context] = []

        for number in range {
            for _ in 0..<max(1, document.printSettings.copiesPerNumber) {
                let context: Context = [
                    "number": formatted(
                        value: "\(number)",
                        format: document.printSettings.numberFormat
                    )
                ]
                contexts.append(resolvedContext(context, for: document))

                if let limit, contexts.count >= limit {
                    return contexts
                }
            }
        }

        return contexts
    }

    private static func values(
        for variable: VariableDefinition,
        document: ZPrintDocument,
        limit: Int?
    ) -> [String] {
        let range = document.printSettings.range(for: variable)
        let startValue = range?.startValue ?? variable.startValue
        let endValue = range?.endValue ?? max(variable.startValue, variable.endValue)
        let copiesPerValue = max(1, range?.copiesPerValue ?? 1)
        let step = max(1, variable.step)

        guard endValue >= startValue else {
            return []
        }

        var values: [String] = []
        var currentValue = startValue

        while currentValue <= endValue {
            for _ in 0..<copiesPerValue {
                values.append("\(currentValue)")

                if let limit, values.count >= limit {
                    return values
                }
            }

            currentValue += step
        }

        return values
    }

    private static func combinedContexts(
        baseContext: Context,
        variables: [VariableDefinition],
        values: [[String]]
    ) -> [Context] {
        guard let variable = variables.first,
              let variableValues = values.first,
              !variableValues.isEmpty else {
            return [baseContext]
        }

        let remainingVariables = Array(variables.dropFirst())
        let remainingValues = Array(values.dropFirst())
        var contexts: [Context] = []

        for value in variableValues {
            var context = baseContext
            context[variable.name] = value
            contexts.append(
                contentsOf: combinedContexts(
                    baseContext: context,
                    variables: remainingVariables,
                    values: remainingValues
                )
            )
        }

        return contexts
    }

    private static func defaultTextValue(for variable: VariableDefinition) -> String {
        if !variable.defaultValue.isEmpty {
            return variable.defaultValue
        }

        switch variable.name.lowercased() {
        case "name":
            return "Name"
        case "week":
            return "\(Calendar.current.component(.weekOfYear, from: Date()))"
        case "amount":
            return "1"
        case "id":
            return "ID"
        default:
            return ""
        }
    }

    static func rawPrintValue(
        for variable: VariableDefinition,
        document: ZPrintDocument
    ) -> String {
        if let value = document.printSettings.printVariableValues[variable.id] {
            return value
        }

        if variable.type == .sequence {
            let range = document.printSettings.range(for: variable)
            return "\(range?.startValue ?? variable.startValue)"
        }


        if variable.type == .tableLookup {
            return lookupFallback(for: variable)
        }

        return defaultTextValue(for: variable)
    }

    static func renderedPrintValue(
        for variable: VariableDefinition,
        document: ZPrintDocument
    ) -> String {
        renderTemplateString(
            variable.placeholder,
            context: [variable.name: rawPrintValue(for: variable, document: document)],
            variables: [variable]
        )
    }

    private static func defaultPreviewValue(for name: String, document: ZPrintDocument) -> String {
        switch name.lowercased() {
        case "number":
            return "\(document.printSettings.counterStart)"
        case "name":
            return "Name"
        case "week":
            return "\(Calendar.current.component(.weekOfYear, from: Date()))"
        case "amount":
            return "1"
        case "id":
            return "ID"
        default:
            return ""
        }
    }

    private static func formatted(value: String, format: String?) -> String {
        guard let format, !format.isEmpty,
              let number = Int(value),
              format.allSatisfy({ $0 == "0" }) else {
            return value
        }

        return String(format: "%0\(format.count)d", number)
    }

    private static func renderedVariableValue(
        _ value: String,
        inlineFormat: String?,
        variable: VariableDefinition?
    ) -> String {
        let formattedValue = formatted(
            value: value,
            format: inlineFormat ?? variable?.format
        )

        guard let variable, variable.type == .sequence else {
            return formattedValue
        }

        if !variable.prefix.isEmpty, formattedValue.hasPrefix(variable.prefix) {
            return formattedValue
        }

        return "\(variable.prefix)\(formattedValue)"
    }

    private static func lookupFallback(for variable: VariableDefinition) -> String {
        let configuredFallback = variable.tableLookup?.fallbackValue ?? ""
        return configuredFallback.isEmpty ? variable.defaultValue : configuredFallback
    }
}
