import SwiftUI

struct EditorView: View {
    @Binding var document: ZPrintDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Label bearbeiten")
                .font(.title2)

            labelSurface

            HStack {
                Button("Text hinzufügen") {
                    document.elements.append(.text(TextLabelElement(xDots: 40, yDots: 40, text: "Neuer Text")))
                }

                Button("Barcode hinzufügen") {
                    document.elements.append(.barcode(BarcodeLabelElement(xDots: 40, yDots: 120, value: "{{number:00000}}")))
                }
            }
        }
        .padding(20)
    }

    private var labelSurface: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.white)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.5)))

            ForEach(document.elements) { element in
                elementView(element)
            }
        }
        .aspectRatio(labelAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var labelAspectRatio: Double {
        Double(document.labelSize.widthDots) / Double(document.labelSize.heightDots)
    }

    @ViewBuilder
    private func elementView(_ element: LabelElement) -> some View {
        switch element {
        case .text(let textElement):
            Text(textElement.text)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .padding(4)
                .background(Color.blue.opacity(0.12))
                .position(x: CGFloat(textElement.xDots) / 2, y: CGFloat(textElement.yDots) / 2)

        case .barcode(let barcodeElement):
            VStack(spacing: 4) {
                Image(systemName: "barcode")
                    .font(.system(size: 40))
                Text(barcodeElement.value)
                    .font(.caption.monospaced())
            }
            .padding(6)
            .background(Color.green.opacity(0.12))
            .position(x: CGFloat(barcodeElement.xDots) / 2, y: CGFloat(barcodeElement.yDots) / 2)
        }
    }
}

#Preview {
    EditorView(document: .constant(ZPrintDocument()))
}
