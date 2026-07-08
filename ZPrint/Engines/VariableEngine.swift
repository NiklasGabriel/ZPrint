import Foundation

enum VariableEngine {
    static func sampleValues(from variables: [String: String]) -> [String: String] {
        variables
    }

    static func resolve(_ template: String, values: [String: String]) -> String {
        var result = template

        for (name, value) in values {
            result = result.replacingOccurrences(of: "{{\(name)}}", with: value)
            result = resolveNumberPlaceholder(in: result, name: name, value: value)
        }

        return result
    }

    private static func resolveNumberPlaceholder(in text: String, name: String, value: String) -> String {
        let pattern = "{{\(name):"
        guard let startRange = text.range(of: pattern) else {
            return text
        }

        guard let endRange = text[startRange.upperBound...].range(of: "}}") else {
            return text
        }

        let format = String(text[startRange.upperBound..<endRange.lowerBound])
        let paddedValue = value.leftPadding(toLength: format.count, withPad: "0")
        let fullRange = startRange.lowerBound..<endRange.upperBound
        return text.replacingCharacters(in: fullRange, with: paddedValue)
    }
}

private extension String {
    func leftPadding(toLength length: Int, withPad pad: Character) -> String {
        guard count < length else { return self }
        return String(repeating: String(pad), count: length - count) + self
    }
}
