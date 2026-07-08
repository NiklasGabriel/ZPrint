import SwiftUI

struct InspectorView: View {
    @Binding var document: ZPrintDocument
    @Binding var selectedElementID: UUID?

    private var selectedElementIndex: Int? {
        guard let selectedElementID else { return nil }
        return document.elements.firstIndex { $0.id == selectedElementID }
    }

    var body: some View {
        Form {
            labelSection
            elementSummarySection
            selectedElementSection
            variablesSection
        }
        .formStyle(.grouped)
    }

    private var labelSection: some View {
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
    }

    private var elementSummarySection: some View {
        Section("Elemente") {
            LabeledContent("Anzahl", value: "\(document.elements.count)")
        }
    }

    @ViewBuilder
    private var selectedElementSection: some View {
        Section("Auswahl") {
            if let index = selectedElementIndex {
                switch document.elements[index] {
                case .text:
                    textElementControls(index: index)
                case .barcode:
                    barcodeElementControls(index: index)
                }
            } else {
                Text("Kein Element ausgewaehlt")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var variablesSection: some View {
        Section("Variablen") {
            if document.variables.isEmpty {
                Text("Keine Variablen")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(document.variables.keys.sorted(), id: \.self) { name in
                    LabeledContent(name, value: document.variables[name] ?? "")
                }
            }
        }
    }

    @ViewBuilder
    private func textElementControls(index: Int) -> some View {
        Stepper("x: \(textBinding(index, \.xDots).wrappedValue)", value: textBinding(index, \.xDots), in: 0...document.label.widthDots)
        Stepper("y: \(textBinding(index, \.yDots).wrappedValue)", value: textBinding(index, \.yDots), in: 0...document.label.heightDots)
        Stepper("w: \(textBinding(index, \.widthDots).wrappedValue)", value: textBinding(index, \.widthDots), in: 1...document.label.widthDots)
        Stepper("h: \(textBinding(index, \.heightDots).wrappedValue)", value: textBinding(index, \.heightDots), in: 1...document.label.heightDots)

        TextField("Textinhalt", text: textBinding(index, \.text), axis: .vertical)
            .lineLimit(2...4)

        Stepper("Schriftgroesse: \(textBinding(index, \.fontSizeDots).wrappedValue)", value: textBinding(index, \.fontSizeDots), in: 6...240)

        Toggle("Fett", isOn: textBinding(index, \.isBold))
        Toggle("Kursiv", isOn: textBinding(index, \.isItalic))
        Toggle("Unterstrichen", isOn: textBinding(index, \.isUnderlined))
    }

    @ViewBuilder
    private func barcodeElementControls(index: Int) -> some View {
        Stepper("x: \(barcodeBinding(index, \.xDots).wrappedValue)", value: barcodeBinding(index, \.xDots), in: 0...document.label.widthDots)
        Stepper("y: \(barcodeBinding(index, \.yDots).wrappedValue)", value: barcodeBinding(index, \.yDots), in: 0...document.label.heightDots)
        Stepper("w: \(barcodeBinding(index, \.widthDots).wrappedValue)", value: barcodeBinding(index, \.widthDots), in: 1...document.label.widthDots)
        Stepper("h: \(barcodeBinding(index, \.heightDots).wrappedValue)", value: barcodeBinding(index, \.heightDots), in: 1...document.label.heightDots)

        TextField("Wert", text: barcodeBinding(index, \.value), axis: .vertical)
            .lineLimit(2...4)

        Picker("Barcode-Typ", selection: barcodeBinding(index, \.barcodeType)) {
            Text("Code128").tag("code128")
        }

        Stepper("Hoehe: \(barcodeBinding(index, \.heightDots).wrappedValue)", value: barcodeBinding(index, \.heightDots), in: 1...document.label.heightDots)
        Stepper("Modulbreite: \(barcodeBinding(index, \.moduleWidth).wrappedValue)", value: barcodeBinding(index, \.moduleWidth), in: 1...10)
        Toggle("Klarschrift", isOn: barcodeBinding(index, \.humanReadable))
    }

    private func textBinding<Value>(_ index: Int, _ keyPath: WritableKeyPath<TextLabelElement, Value>) -> Binding<Value> {
        Binding(
            get: {
                guard index < document.elements.count,
                      case .text(let element) = document.elements[index]
                else {
                    return TextLabelElement()[keyPath: keyPath]
                }

                return element[keyPath: keyPath]
            },
            set: { newValue in
                guard index < document.elements.count,
                      case .text(var element) = document.elements[index]
                else { return }

                element[keyPath: keyPath] = newValue
                document.elements[index] = .text(element)
            }
        )
    }

    private func barcodeBinding<Value>(_ index: Int, _ keyPath: WritableKeyPath<BarcodeLabelElement, Value>) -> Binding<Value> {
        Binding(
            get: {
                guard index < document.elements.count,
                      case .barcode(let element) = document.elements[index]
                else {
                    return BarcodeLabelElement()[keyPath: keyPath]
                }

                return element[keyPath: keyPath]
            },
            set: { newValue in
                guard index < document.elements.count,
                      case .barcode(var element) = document.elements[index]
                else { return }

                element[keyPath: keyPath] = newValue
                document.elements[index] = .barcode(element)
            }
        )
    }
}

#Preview {
    @Previewable @State var document = ZPrintDocument(elements: [.text(TextLabelElement())])
    @Previewable @State var selectedElementID: UUID? = document.elements.first?.id

    InspectorView(document: $document, selectedElementID: $selectedElementID)
}
