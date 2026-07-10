//
//  ZPLPDFRenderer.swift
//  ZPrint
//

import Foundation

struct ZPLPDFRenderer {
    static func renderPDF(
        zpl: String,
        labelSize: LabelSize
    ) async throws -> Data {
        let trimmedZPL = zpl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedZPL.isEmpty else {
            throw ZPLPDFRendererError.emptyZPL
        }

        var request = URLRequest(url: try renderURL(for: labelSize))
        request.httpMethod = "POST"
        request.setValue("application/pdf", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("On", forHTTPHeaderField: "X-Linter")
        request.httpBody = Data(trimmedZPL.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZPLPDFRendererError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw ZPLPDFRendererError.renderingFailed(statusCode: httpResponse.statusCode, message: message)
        }

        guard data.starts(with: Data("%PDF".utf8)) else {
            throw ZPLPDFRendererError.invalidPDF
        }

        return data
    }

    private static func renderURL(for labelSize: LabelSize) throws -> URL {
        let dpmm = labelaryDensity(for: labelSize.dotsPerInch)
        let width = labelaryNumber(Double(labelSize.widthDots) / Double(labelSize.dotsPerInch))
        let height = labelaryNumber(Double(labelSize.heightDots) / Double(labelSize.dotsPerInch))
        let urlString = "https://api.labelary.com/v1/printers/\(dpmm)/labels/\(width)x\(height)/"

        guard let url = URL(string: urlString) else {
            throw ZPLPDFRendererError.invalidURL
        }

        return url
    }

    private static func labelaryDensity(for dpi: Int) -> String {
        let supportedDensities = [
            (dpi: 152, dpmm: "6dpmm"),
            (dpi: 203, dpmm: "8dpmm"),
            (dpi: 300, dpmm: "12dpmm"),
            (dpi: 600, dpmm: "24dpmm")
        ]

        return supportedDensities
            .min { abs($0.dpi - dpi) < abs($1.dpi - dpi) }?
            .dpmm ?? "12dpmm"
    }

    private static func labelaryNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

enum ZPLPDFRendererError: Error, LocalizedError {
    case emptyZPL
    case invalidURL
    case invalidResponse
    case invalidPDF
    case renderingFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .emptyZPL:
            return "Der ZPL-Inhalt ist leer."
        case .invalidURL:
            return "Die PDF-Renderer-URL konnte nicht erstellt werden."
        case .invalidResponse:
            return "Der PDF-Renderer hat keine gültige HTTP-Antwort geliefert."
        case .invalidPDF:
            return "Der PDF-Renderer hat keine gültige PDF-Datei zurückgegeben."
        case .renderingFailed(let statusCode, let message):
            return "ZPL-PDF konnte nicht erzeugt werden (HTTP \(statusCode)): \(message)"
        }
    }
}
