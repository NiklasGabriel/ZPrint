import SwiftUI

struct PreviewModeView: View {
    let document: ZPrintDocument

    private var variableValues: [String: String] {
        VariableEngine.sampleValues(from: document.variables)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ZPL Vorschau")
                .font(.title2)

            TextEditor(text: .constant(ZPLEngine.makeZPL(for: document, variableValues: variableValues)))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(Rectangle().stroke(Color.gray.opacity(0.3)))
        }
        .padding(20)
    }
}

#Preview {
    PreviewModeView(document: ZPrintDocument())
}
