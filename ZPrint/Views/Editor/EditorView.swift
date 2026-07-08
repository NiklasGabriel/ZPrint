import SwiftUI

struct EditorView: View {
    @Binding var document: ZPrintDocument
    @Binding var selectedElementID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Label bearbeiten")
                .font(.title2)

            LabelCanvasView(document: $document, selectedElementID: $selectedElementID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("Text hinzufügen") {
                    let element = LabelElement.text(TextLabelElement())
                    document.elements.append(element)
                    selectedElementID = element.id
                }

                Button("Barcode hinzufügen") {
                    let element = LabelElement.barcode(BarcodeLabelElement())
                    document.elements.append(element)
                    selectedElementID = element.id
                }
            }
        }
        .padding(20)
    }
}

#Preview {
    @Previewable @State var document = ZPrintDocument()
    @Previewable @State var selectedElementID: UUID?

    EditorView(document: $document, selectedElementID: $selectedElementID)
}
