//
//  LabelImageImporter.swift
//  ZPrint
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum LabelImageImporter {
    static let allowedContentTypes: [UTType] = [.image, .svg]

    static func load(from url: URL) throws -> ImportedLabelImage {
        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty, let image = NSImage(data: data) else {
            throw LabelImageImportError.unreadableImage
        }

        let size = intrinsicPixelSize(of: image)
        let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        let mediaType = contentType?.preferredMIMEType
            ?? (url.pathExtension.lowercased() == "svg" ? "image/svg+xml" : "application/octet-stream")

        return ImportedLabelImage(
            fileName: url.lastPathComponent,
            mediaType: mediaType,
            data: data,
            width: max(1, Int(round(size.width))),
            height: max(1, Int(round(size.height)))
        )
    }

    static func image(from data: Data) -> NSImage? {
        NSImage(data: data)
    }

    private static func intrinsicPixelSize(of image: NSImage) -> NSSize {
        if image.size.width > 0, image.size.height > 0 {
            return image.size
        }

        if let bitmap = image.representations
            .compactMap({ $0 as? NSBitmapImageRep })
            .max(by: { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }),
           bitmap.pixelsWide > 0,
           bitmap.pixelsHigh > 0 {
            return NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        }

        return NSSize(width: 1, height: 1)
    }
}

struct ImportedLabelImage {
    let fileName: String
    let mediaType: String
    let data: Data
    let width: Int
    let height: Int

    var aspectRatio: Double {
        Double(max(1, width)) / Double(max(1, height))
    }
}

enum LabelImageImportError: Error, LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "Die ausgewählte Datei konnte nicht als Bild oder SVG gelesen werden."
        }
    }
}
