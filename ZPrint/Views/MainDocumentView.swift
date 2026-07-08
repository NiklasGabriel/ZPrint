import SwiftUI

enum MainDocumentMode: String, CaseIterable, Identifiable {
    case editor = "Bearbeiten"
    case preview = "Vorschau"
    case print = "Drucken"

    var id: String { rawValue }
}

struct MainDocumentView: View {
    @Binding var document: ZPrintDocument
    @State private var mode: MainDocumentMode = .editor
    @State private var selectedElementID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            TopToolbarView(mode: $mode)

            Divider()

            HSplitView {
                contentView
                    .frame(minWidth: 520, minHeight: 360)

                InspectorView(document: $document, selectedElementID: $selectedElementID)
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
            }
        }
        .frame(minWidth: 820, minHeight: 520)
        .onChange(of: document.elements) { _, elements in
            guard let selectedElementID,
                  elements.contains(where: { $0.id == selectedElementID })
            else {
                self.selectedElementID = nil
                return
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch mode {
        case .editor:
            EditorView(document: $document, selectedElementID: $selectedElementID)
        case .preview:
            PreviewModeView(document: document)
        case .print:
            PrintModeView(document: $document)
        }
    }
}

#Preview {
    MainDocumentView(document: .constant(ZPrintDocument()))
}
