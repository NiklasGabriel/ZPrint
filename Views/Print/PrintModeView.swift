import SwiftUI

struct PrintModeView: View {
    @Binding var document: ZPrintDocument

    private var zebraPrinters: [ZebraPrinter] {
        PrinterManager.installedZebraPrinters()
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

            Stepper("Kopien: \(document.printSettings.copies)", value: $document.printSettings.copies, in: 1...999)

            Button("ZPL senden") {}
                .disabled(true)

            Text("Der direkte ZPL-Druckpfad wird in einem spaeteren Schritt angeschlossen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    PrintModeView(document: .constant(ZPrintDocument()))
}
