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
        .system(
            size: max(7, scale.points(fromDots: element.fontSizeDots)),
            weight: element.isBold ? .semibold : .regular
        )
    }

    private func barcodeElementView(_ element: BarcodeLabelElement) -> some View {
        VStack(spacing: 3) {
            PreviewBarcodeBarsView(
                value: element.value,
                moduleWidth: max(1, scale.points(fromDots: element.moduleWidth))
            )
            .frame(maxHeight: .infinity)

            if element.showsHumanReadableText {
                Text(element.value)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.9), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func shapeElementView(_ element: ShapeLabelElement) -> some View {
        switch element.shape {
        case .rectangle:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(element.isFilled ? Color.black.opacity(0.10) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(Color.black.opacity(0.86), lineWidth: max(1, scale.points(fromDots: element.strokeWidthDots)))
                }
        case .ellipse:
            Ellipse()
                .fill(element.isFilled ? Color.black.opacity(0.10) : Color.clear)
                .overlay {
                    Ellipse()
                        .stroke(Color.black.opacity(0.86), lineWidth: max(1, scale.points(fromDots: element.strokeWidthDots)))
                }
        case .line:
            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(Color.black.opacity(0.86), lineWidth: max(1, scale.points(fromDots: element.strokeWidthDots)))
            }
        }
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
    let moduleWidth: CGFloat

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
                let quietZoneModules = 10
                let fittedModuleWidth = min(
                    moduleWidth,
                    proxy.size.width / CGFloat(max(totalModules + (quietZoneModules * 2), 1))
                )

                HStack(alignment: .bottom, spacing: 0) {
                    Color.clear
                        .frame(width: CGFloat(quietZoneModules) * fittedModuleWidth)

                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.isBar ? Color.black : Color.clear)
                            .frame(
                                width: CGFloat(segment.widthModules) * fittedModuleWidth,
                                height: proxy.size.height
                            )
                    }

                    Color.clear
                        .frame(width: CGFloat(quietZoneModules) * fittedModuleWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}
