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
            if !variable.defaultValue.isEmpty {
                context[variable.name] = variable.defaultValue
            } else if variable.type == .sequence {
                context[variable.name] = "\(variable.startValue)"
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

    private static func renderedValue(
        for name: String,
        inlineFormat: String?,
        variable: VariableDefinition?,
        context: Context
    ) -> String {
        if let value = context[name], !value.isEmpty {
            return formatted(value: value, format: inlineFormat ?? variable?.format)
        }

        if let variable, !variable.defaultValue.isEmpty {
            return formatted(value: variable.defaultValue, format: inlineFormat ?? variable.format)
        }

        if variable?.type == .sequence || inlineFormat != nil {
            return formatted(value: "\(variable?.startValue ?? 1)", format: inlineFormat ?? variable?.format)
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
}
