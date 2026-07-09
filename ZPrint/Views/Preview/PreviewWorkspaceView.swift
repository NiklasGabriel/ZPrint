//
//  PreviewWorkspaceView.swift
//  ZPrint
//

import SwiftUI

struct PreviewWorkspaceView: View {
    @Binding var document: ZPrintDocument
    @Binding var previewContext: VariableEngine.Context
    @State private var zoomGestureStart: Double?

    init(
        document: Binding<ZPrintDocument>,
        previewContext: Binding<VariableEngine.Context>
    ) {
        _document = document
        _previewContext = previewContext
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(nsColor: .underPageBackgroundColor)

                ScrollView([.horizontal, .vertical]) {
                    previewLabelSurface
                    .padding(.horizontal, 42)
                    .padding(.vertical, 32)
                    .frame(
                        minWidth: proxy.size.width,
                        minHeight: proxy.size.height,
                        alignment: .center
                    )
                }
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear {
            normalizeContext()
        }
        .onChange(of: document.variables) { _, _ in
            normalizeContext()
        }
        .onChange(of: document.printSettings) { _, _ in
            normalizeContext()
        }
        .simultaneousGesture(trackpadZoomGesture)
    }

    private var previewLabelSurface: some View {
        let labelSize = scale.size(for: document.label)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .frame(width: labelSize.width, height: labelSize.height)

            ForEach(document.elements) { element in
                previewElementLayer(element)
            }
        }
        .frame(width: labelSize.width, height: labelSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
    }

    private var scale: DotViewScale {
        DotViewScale(zoomScale: document.viewSettings.zoomScale)
    }

    private var variableEngine: VariableEngine {
        VariableEngine(variables: document.variables)
    }

    private func previewElementLayer(_ element: LabelElement) -> some View {
        let rect = scale.rect(for: element.frame)

        return PreviewLabelElementView(
            element: renderedElement(element),
            scale: scale
        )
        .frame(width: max(1, rect.width), height: max(1, rect.height))
        .rotationEffect(.degrees(Double(element.rotation.degrees)))
        .position(x: rect.midX, y: rect.midY)
    }

    private func renderedElement(_ element: LabelElement) -> LabelElement {
        switch element {
        case .text(var textElement):
            textElement.text = variableEngine.renderTemplateString(
                textElement.text,
                context: previewContext
            )
            return .text(textElement)
        case .barcode(var barcodeElement):
            barcodeElement.value = variableEngine.renderTemplateString(
                barcodeElement.value,
                context: previewContext
            )
            return .barcode(barcodeElement)
        case .shape:
            return element
        }
    }

    private func normalizeContext() {
        previewContext = VariableEngine.normalizedPreviewContext(previewContext, for: document)
    }

    private var trackpadZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { magnification in
                if zoomGestureStart == nil {
                    zoomGestureStart = document.viewSettings.zoomScale
                }

                let startZoom = zoomGestureStart ?? document.viewSettings.zoomScale
                document.viewSettings.zoomScale = min(max(startZoom * magnification, 0.25), 3.0)
            }
            .onEnded { _ in
                zoomGestureStart = nil
            }
    }
}

private struct PreviewLabelElementView: View {
    let element: LabelElement
    let scale: DotViewScale

    var body: some View {
        ZStack {
            switch element {
            case .text(let textElement):
                textElementView(textElement)
            case .barcode(let barcodeElement):
                barcodeElementView(barcodeElement)
            case .shape(let shapeElement):
                shapeElementView(shapeElement)
            }
        }
    }

    private func textElementView(_ element: TextLabelElement) -> some View {
        Text(element.text)
            .font(textFont(for: element))
            .foregroundStyle(.primary)
            .italic(element.isItalic)
            .underline(element.isUnderlined)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: element.alignment.previewAlignment)
    }

    private func textFont(for element: TextLabelElement) -> Font {
        TextLabelFontCatalog.swiftUIFont(
            familyName: element.fontFamilyName,
            size: max(7, scale.points(fromDots: element.fontSizeDots)),
            isBold: element.isBold
        )
    }

    private func barcodeElementView(_ element: BarcodeLabelElement) -> some View {
        VStack(spacing: 0) {
            PreviewBarcodeBarsView(value: element.value)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if element.showsHumanReadableText {
                Text(element.value)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func shapeElementView(_ element: ShapeLabelElement) -> some View {
        let fillColor = element.isFilled ? Color(labelElementColor: element.fillColor) : Color.clear
        let strokeColor = Color(labelElementColor: element.strokeColor)
        let strokeWidth = max(1, scale.points(fromDots: element.strokeWidthDots))

        switch element.shape {
        case .rectangle:
            Rectangle()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        Rectangle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .ellipse:
            Ellipse()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        Ellipse()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .capsule:
            Capsule()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        Capsule()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .triangle:
            PreviewTriangleShape()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        PreviewTriangleShape()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .line:
            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(strokeColor, lineWidth: strokeWidth)
            }
        }
    }
}

private struct PreviewTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private extension Color {
    init(labelElementColor color: LabelElementColor) {
        self.init(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: color.alpha
        )
    }
}

private extension TextElementAlignment {
    var previewAlignment: Alignment {
        switch self {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }
}

private struct PreviewBarcodeBarsView: View {
    let value: String

    var body: some View {
        let segments = Code128Barcode.segments(for: value)

        return GeometryReader { proxy in
            if segments.isEmpty {
                Text("Kein Wert")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let totalModules = segments.reduce(0) { $0 + $1.widthModules }
                let fittedModuleWidth = proxy.size.width / CGFloat(max(totalModules, 1))

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.isBar ? Color.black : Color.clear)
                            .frame(
                                width: CGFloat(segment.widthModules) * fittedModuleWidth,
                                height: proxy.size.height
                            )
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            }
        }
    }
}
