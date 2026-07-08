import SwiftUI

struct InspectorView: View {
    @Binding var document: ZPrintDocument

    var body: some View {
        Form {
            Section("Label") {
                Picker("Groesse", selection: $document.labelSize) {
                    ForEach(LabelSize.presets) { size in
                        Text(size.name).tag(size)
                    }
                }

                LabeledContent("Breite", value: "\(document.labelSize.widthDots) dots")
                LabeledContent("Hoehe", value: "\(document.labelSize.heightDots) dots")
                LabeledContent("DPI", value: "\(document.labelSize.dpi)")
            }

            Section("Elemente") {
                LabeledContent("Anzahl", value: "\(document.elements.count)")
            }

            Section("Variablen") {
                ForEach(document.variables) { variable in
                    LabeledContent(variable.name, value: variable.sampleValue)
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    InspectorView(document: .constant(ZPrintDocument()))
}
