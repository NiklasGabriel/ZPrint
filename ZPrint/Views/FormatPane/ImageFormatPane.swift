//
//  ImageFormatPane.swift
//  ZPrint
//

import SwiftUI

struct ImageFormatPane: View {
    @Binding var element: ImageLabelElement
    let labelSize: LabelSize
    let delete: () -> Void
    @State private var isShowingImporter = false
    @State private var importErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormatSection(title: "Bild") {
                LabelImageView(imageData: element.imageData)
                    .aspectRatio(element.sourceAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 116)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                PropertyValueRow(title: "Datei", value: element.fileName)
                PropertyValueRow(title: "Format", value: element.formatDisplayName)

                Button {
                    isShowingImporter = true
                } label: {
                    Label("Datei ersetzen", systemImage: "arrow.triangle.2.circlepath")
                }
                .controlSize(.small)
            }

            FormatSection(title: "Größe und Position") {
                Toggle("Seitenverhältnis sperren", isOn: $element.locksAspectRatio)
                    .controlSize(.small)
                IntegerPropertyField(title: "X", value: frameBinding(\.xDots))
                IntegerPropertyField(title: "Y", value: frameBinding(\.yDots))
                IntegerPropertyField(title: "Breite", value: widthBinding)
                IntegerPropertyField(title: "Höhe", value: heightBinding)
                IntegerPropertyField(title: "Drehung", value: rotationBinding)
            }

            FormatSection(title: "Aktionen") {
                Button(role: .destructive, action: delete) {
                    Label("Bild löschen", systemImage: "trash")
                }
                .controlSize(.small)
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: LabelImageImporter.allowedContentTypes,
            allowsMultipleSelection: false,
            onCompletion: replaceImage
        )
        .alert("Bild konnte nicht geladen werden", isPresented: importErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "Unbekannter Fehler")
        }
    }

    private var widthBinding: Binding<Int> {
        Binding(
            get: { element.frame.widthDots },
            set: { newValue in
                var frame = element.frame
                frame.widthDots = max(1, newValue)
                if element.locksAspectRatio {
                    frame.heightDots = max(1, Int(round(Double(frame.widthDots) / element.sourceAspectRatio)))
                }
                element.frame = frame
            }
        )
    }

    private var heightBinding: Binding<Int> {
        Binding(
            get: { element.frame.heightDots },
            set: { newValue in
                var frame = element.frame
                frame.heightDots = max(1, newValue)
                if element.locksAspectRatio {
                    frame.widthDots = max(1, Int(round(Double(frame.heightDots) * element.sourceAspectRatio)))
                }
                element.frame = frame
            }
        )
    }

    private func frameBinding(_ keyPath: WritableKeyPath<LabelElementFrame, Int>) -> Binding<Int> {
        Binding(
            get: { element.frame[keyPath: keyPath] },
            set: { newValue in
                var frame = element.frame
                frame[keyPath: keyPath] = newValue
                element.frame = frame
            }
        )
    }

    private var rotationBinding: Binding<Int> {
        Binding(
            get: { element.rotation.degrees },
            set: { element.rotation = LabelElementRotation(degrees: $0) }
        )
    }

    private var importErrorPresented: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )
    }

    private func replaceImage(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let importedImage = try LabelImageImporter.load(from: url)
            element.fileName = importedImage.fileName
            element.name = importedImage.fileName
            element.mediaType = importedImage.mediaType
            element.imageData = importedImage.data
            element.sourceWidth = importedImage.width
            element.sourceHeight = importedImage.height

            if element.locksAspectRatio {
                element.frame = fittedReplacementFrame(aspectRatio: importedImage.aspectRatio)
            }
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func fittedReplacementFrame(aspectRatio: Double) -> LabelElementFrame {
        let ratio = max(0.01, aspectRatio)
        var frame = element.frame
        let availableWidth = max(1, labelSize.widthDots - max(0, frame.xDots))
        let availableHeight = max(1, labelSize.heightDots - max(0, frame.yDots))
        var width = min(max(1, frame.widthDots), availableWidth)
        var height = max(1, Int(round(Double(width) / ratio)))

        if height > availableHeight {
            height = availableHeight
            width = max(1, Int(round(Double(height) * ratio)))
        }

        frame.widthDots = width
        frame.heightDots = height
        return frame.clamped(to: labelSize)
    }
}
