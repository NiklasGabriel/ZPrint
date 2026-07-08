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

    var body: some View {
        VStack(spacing: 0) {
            TopToolbarView(mode: $mode)

            Divider()

            HSplitView {
                contentView
                    .frame(minWidth: 520, minHeight: 360)

                InspectorView(document: $document)
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 340)
            }
        }
        .frame(minWidth: 820, minHeight: 520)
    }

    @ViewBuilder
    private var contentView: some View {
        switch mode {
        case .editor:
            EditorView(document: $document)
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
