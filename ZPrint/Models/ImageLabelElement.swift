//
//  ImageLabelElement.swift
//  ZPrint
//

import Foundation

struct ImageLabelElement: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var frame: LabelElementFrame
    var fileName: String
    var mediaType: String
    var imageData: Data
    var sourceWidth: Int
    var sourceHeight: Int
    var locksAspectRatio: Bool
    var rotation: LabelElementRotation

    init(
        id: UUID = UUID(),
        name: String = "Bild",
        frame: LabelElementFrame = .zero,
        fileName: String,
        mediaType: String,
        imageData: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        locksAspectRatio: Bool = true,
        rotation: LabelElementRotation = .degrees0
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.fileName = fileName
        self.mediaType = mediaType
        self.imageData = imageData
        self.sourceWidth = max(1, sourceWidth)
        self.sourceHeight = max(1, sourceHeight)
        self.locksAspectRatio = locksAspectRatio
        self.rotation = rotation
    }

    var sourceAspectRatio: Double {
        Double(max(1, sourceWidth)) / Double(max(1, sourceHeight))
    }

    var formatDisplayName: String {
        if mediaType == "image/svg+xml" {
            return "SVG"
        }

        let fileExtension = (fileName as NSString).pathExtension
        return fileExtension.isEmpty ? "Bild" : fileExtension.uppercased()
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case frame
        case fileName
        case mediaType
        case imageData
        case sourceWidth
        case sourceHeight
        case locksAspectRatio
        case rotation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = container.decodeOrDefault(UUID.self, forKey: .id, default: UUID())
        name = container.decodeOrDefault(String.self, forKey: .name, default: "Bild")
        frame = container.decodeOrDefault(LabelElementFrame.self, forKey: .frame, default: .zero)
        fileName = container.decodeOrDefault(String.self, forKey: .fileName, default: "Bild")
        mediaType = container.decodeOrDefault(String.self, forKey: .mediaType, default: "application/octet-stream")
        imageData = container.decodeOrDefault(Data.self, forKey: .imageData, default: Data())
        sourceWidth = max(1, container.decodeOrDefault(Int.self, forKey: .sourceWidth, default: 1))
        sourceHeight = max(1, container.decodeOrDefault(Int.self, forKey: .sourceHeight, default: 1))
        locksAspectRatio = container.decodeOrDefault(Bool.self, forKey: .locksAspectRatio, default: true)
        rotation = container.decodeOrDefault(LabelElementRotation.self, forKey: .rotation, default: .degrees0)
    }
}
