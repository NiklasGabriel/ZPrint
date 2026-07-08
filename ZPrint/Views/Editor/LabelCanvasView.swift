import SwiftUI

struct LabelCanvasView: View {
    @Binding var document: ZPrintDocument
    @Binding var selectedElementID: UUID?
    @State private var dragStartPositions: [UUID: CGPoint] = [:]

    var body: some View {
        GeometryReader { geometry in
            let layout = canvasLayout(in: geometry.size)

            ZStack {
                Color(nsColor: .controlBackgroundColor)

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.white)
                        .overlay(Rectangle().stroke(Color.gray.opacity(0.45), lineWidth: 1))

                    ForEach(document.elements) { element in
                        elementView(element, scale: layout.scale)
                    }
                }
                .frame(width: layout.size.width, height: layout.size.height)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            }
        }
    }

    private func canvasLayout(in availableSize: CGSize) -> (size: CGSize, scale: CGFloat) {
        let labelWidth = max(CGFloat(document.label.widthDots), 1)
        let labelHeight = max(CGFloat(document.label.heightDots), 1)
        let scale = min(availableSize.width / labelWidth, availableSize.height / labelHeight)
        let safeScale = max(scale, 0.1)
        return (CGSize(width: labelWidth * safeScale, height: labelHeight * safeScale), safeScale)
    }

    @ViewBuilder
    private func elementView(_ element: LabelElement, scale: CGFloat) -> some View {
        let isSelected = selectedElementID == element.id

        elementContent(element, scale: scale)
            .frame(
                width: CGFloat(element.widthDots) * scale,
                height: CGFloat(element.heightDots) * scale,
                alignment: .topLeading
            )
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.35), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
            .offset(x: CGFloat(element.xDots) * scale, y: CGFloat(element.yDots) * scale)
            .gesture(dragGesture(for: element, scale: scale))
    }

    @ViewBuilder
    private func elementContent(_ element: LabelElement, scale: CGFloat) -> some View {
        switch element {
        case .text(let textElement):
            Text(textElement.text)
                .font(.system(size: max(CGFloat(textElement.fontSizeDots) * scale, 8), weight: .regular, design: .monospaced))
                .foregroundStyle(.black)
                .lineLimit(1)
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

        case .barcode(let barcodeElement):
            VStack(spacing: 4) {
                Image(systemName: "barcode")
                    .font(.system(size: max(CGFloat(barcodeElement.heightDots) * scale * 0.48, 18)))
                    .frame(maxWidth: .infinity)

                if barcodeElement.humanReadable {
                    Text(barcodeElement.value)
                        .font(.system(size: max(10, 12 * scale), design: .monospaced))
                        .lineLimit(1)
                        .foregroundStyle(.black)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func dragGesture(for element: LabelElement, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                selectedElementID = element.id

                if dragStartPositions[element.id] == nil {
                    dragStartPositions[element.id] = CGPoint(x: element.xDots, y: element.yDots)
                }

                guard let startPosition = dragStartPositions[element.id] else { return }

                let deltaXDots = Int((value.translation.width / scale).rounded())
                let deltaYDots = Int((value.translation.height / scale).rounded())
                let newX = Int(startPosition.x) + deltaXDots
                let newY = Int(startPosition.y) + deltaYDots

                moveElement(element.id, toXDots: newX, yDots: newY)
            }
            .onEnded { _ in
                dragStartPositions[element.id] = nil
            }
    }

    private func moveElement(_ id: UUID, toXDots xDots: Int, yDots: Int) {
        guard let index = document.elements.firstIndex(where: { $0.id == id }) else { return }

        let element = document.elements[index]
        let maxX = max(document.label.widthDots - element.widthDots, 0)
        let maxY = max(document.label.heightDots - element.heightDots, 0)
        let clampedX = min(max(xDots, 0), maxX)
        let clampedY = min(max(yDots, 0), maxY)

        document.elements[index].move(toXDots: clampedX, yDots: clampedY)
    }
}

#Preview {
    @Previewable @State var document = ZPrintDocument(
        elements: [
            .text(TextLabelElement()),
            .barcode(BarcodeLabelElement())
        ]
    )
    @Previewable @State var selectedElementID: UUID?

    LabelCanvasView(document: $document, selectedElementID: $selectedElementID)
        .frame(width: 700, height: 420)
}
