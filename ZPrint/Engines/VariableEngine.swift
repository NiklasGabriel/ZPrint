//
//  VariableEngine.swift
//  ZPrint
//

import Foundation

struct VariableEngine {
    typealias Context = [String: String]

    var variables: [VariableDefinition]

    init(variables: [VariableDefinition] = VariableDefinition.standardVariables) {
        self.variables = variables
    }

    func renderTemplateString(_ text: String, context: Context = [:]) -> String {
        Self.renderTemplateString(text, context: context, variables: variables)
    }

    static func renderTemplateString(
        _ text: String,
        context: Context = [:],
        variables: [VariableDefinition] = VariableDefinition.standardVariables
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
            if variable.type == .sequence {
                let printRange = document.printSettings.range(for: variable)
                context[variable.name] = "\(printRange?.startValue ?? variable.startValue)"
            } else {
                context[variable.name] = defaultPreviewValue(for: variable.name, document: document)
            }
        }

        return context
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

        return normalized
    }

    static func batchContexts(for document: ZPrintDocument) -> [Context] {
        let sequenceVariables = document.variables.filter { $0.type == .sequence }

        guard !sequenceVariables.isEmpty else {
            return fallbackCounterContexts(for: document)
        }

        var baseContext = Context()
        for variable in document.variables where variable.type == .text {
            baseContext[variable.name] = defaultTextValue(for: variable)
        }

        let variableValues = sequenceVariables.map { variable in
            values(for: variable, document: document)
        }

        return combinedContexts(
            baseContext: baseContext,
            variables: sequenceVariables,
            values: variableValues
        )
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

    private static func fallbackCounterContexts(for document: ZPrintDocument) -> [Context] {
        guard document.printSettings.counterEnd >= document.printSettings.counterStart else {
            return []
        }

        let range = document.printSettings.counterStart...document.printSettings.counterEnd
        var contexts: [Context] = []

        for number in range {
            for _ in 0..<max(1, document.printSettings.copiesPerNumber) {
                contexts.append([
                    "number": formatted(
                        value: "\(number)",
                        format: document.printSettings.numberFormat
                    )
                ])
            }
        }

        return contexts
    }

    private static func values(
        for variable: VariableDefinition,
        document: ZPrintDocument
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

        return "\(variable.prefix)\(formattedValue)"
    }
}
