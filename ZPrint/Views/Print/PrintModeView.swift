import AppKit
import SwiftUI

struct PrintModeView: View {
    @Binding var document: ZPrintDocument
    @State private var showingZPL = false

    private var zebraPrinters: [ZebraPrinter] {
        PrinterManager.installedZebraPrinters()
    }

    private var zpl: String {
        ZPLEngine.generateZPL(
            document: document,
            context: ZPLGenerationContext(variables: document.variables)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Drucken")
                .font(.title2)

            Text("Installierte Zebra-Drucker")
                .font(.headline)

            if zebraPrinters.isEmpty {
                Text("Noch kein Zebra-Drucker gefunden.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(zebraPrinters) { printer in
                    Text(printer.name)
                }
            }

            Stepper("Kopien: \(document.printSettings.copiesPerNumber)", value: $document.printSettings.copiesPerNumber, in: 1...999)

            HStack {
                Button("ZPL anzeigen") {
                    showingZPL = true
                }

                Button("ZPL senden") {}
                    .disabled(true)
            }

            Text("Der direkte ZPL-Druckpfad wird in einem spaeteren Schritt angeschlossen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingZPL) {
            ZPLSheetView(zpl: zpl)
        }
    }
}

private struct ZPLSheetView: View {
    let zpl: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ZPL")
                    .font(.title3)

                Spacer()

                Button("ZPL kopieren") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(zpl, forType: .string)
                }

                Button("Schliessen") {
                    dismiss()
                }
            }

            TextEditor(text: .constant(zpl))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(Rectangle().stroke(Color.gray.opacity(0.3)))
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 460)
    }
}

#Preview {
    PrintModeView(document: .constant(ZPrintDocument()))
}
