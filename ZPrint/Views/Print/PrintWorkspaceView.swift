//
//  PrintWorkspaceView.swift
//  ZPrint
//

import SwiftUI

struct PrintWorkspaceView: View {
    @Binding var document: ZPrintDocument
    @ObservedObject var printController: PrintJobController
    @State private var zoomGestureStart: Double?

    private var contexts: [VariableEngine.Context] {
        VariableEngine.batchContexts(for: document)
    }

    private var runningVariable: VariableDefinition? {
        document.printSettings.runningVariable(in: document.variables)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ZPrintDesign.ColorToken.workspaceBackground

                if contexts.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView([.vertical, .horizontal]) {
                        LazyVStack(alignment: .center, spacing: 22) {
                            ForEach(Array(contexts.enumerated()), id: \.offset) { index, context in
                                PrintPreviewLabelRow(
                                    index: index + 1,
                                    document: document,
                                    context: context,
                                    runningVariable: runningVariable
                                )
                            }
                        }
                        .padding(.horizontal, 48)
                        .padding(.vertical, 34)
                        .frame(
                            minWidth: proxy.size.width,
                            minHeight: proxy.size.height,
                            alignment: .top
                        )
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .simultaneousGesture(trackpadZoomGesture)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "printer")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Keine Druckvorschau")
                .font(.system(size: 16, weight: .semibold))

            Text("Prüfe Laufvariable, Start, Ende und Anzahl pro Wert.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
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

private struct PrintPreviewLabelRow: View {
    let index: Int
    let document: ZPrintDocument
    let context: VariableEngine.Context
    let runningVariable: VariableDefinition?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .trailing, spacing: 4) {
                Text("Label \(index)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if let runningVariable {
                    Text("\(runningVariable.name) = \(runningValueText(for: runningVariable))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 118, alignment: .trailing)
            .padding(.top, 10)

            PrintPreviewLabelSurface(
                document: document,
                context: context
            )
        }
    }

    private func runningValueText(for variable: VariableDefinition) -> String {
        VariableEngine
            .renderTemplateString(
                variable.placeholder,
                context: context,
                variables: [variable]
            )
    }
}

private struct PrintPreviewLabelSurface: View {
    let document: ZPrintDocument
    let context: VariableEngine.Context

    private var scale: DotViewScale {
        DotViewScale(zoomScale: document.viewSettings.zoomScale)
    }

    private var variableEngine: VariableEngine {
        VariableEngine(variables: document.variables)
    }

    var body: some View {
        let labelSize = scale.size(for: document.label)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .frame(width: labelSize.width, height: labelSize.height)

            ForEach(document.elements) { element in
                elementLayer(element)
            }
        }
        .frame(width: labelSize.width, height: labelSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 7)
    }

    private func elementLayer(_ element: LabelElement) -> some View {
        let rect = scale.rect(for: element.frame)

        return PrintPreviewElementView(
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
                context: context
            )
            return .text(textElement)
        case .barcode(var barcodeElement):
            barcodeElement.value = variableEngine.renderTemplateString(
                barcodeElement.value,
                context: context
            )
            return .barcode(barcodeElement)
        case .shape:
            return element
        }
    }
}

private struct PrintPreviewElementView: View {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: element.alignment.printPreviewAlignment)
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
            PrintPreviewBarcodeBarsView(value: element.value)
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
        let fillColor = element.isFilled ? Color(printLabelElementColor: element.fillColor) : Color.clear
        let strokeColor = Color(printLabelElementColor: element.strokeColor)
        let strokeWidth = max(1, scale.points(fromDots: element.strokeWidthDots))

        switch element.shape {
        case .rectangle:
            Rectangle()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        Rectangle().stroke(strokeColor, lineWidth: strokeWidth)
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
                        Ellipse().stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .capsule:
            Capsule()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        Capsule().stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .triangle:
            PrintPreviewTriangleShape()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        PrintPreviewTriangleShape().stroke(strokeColor, lineWidth: strokeWidth)
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

private struct PrintPreviewBarcodeBarsView: View {
    let value: String

    var body: some View {
        let segments = Code128Barcode.segments(for: value)

        GeometryReader { proxy in
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

private struct PrintPreviewTriangleShape: Shape {
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
    init(printLabelElementColor color: LabelElementColor) {
        self.init(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: color.alpha
        )
    }
}

private extension TextElementAlignment {
    var printPreviewAlignment: Alignment {
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
