import AppKit
import Foundation

struct ZebraPrinter: Identifiable, Hashable {
    var id: String { name }
    var name: String
}

enum PrinterManager {
    static func installedPrinters() -> [ZebraPrinter] {
        NSPrinter.printerNames.map { ZebraPrinter(name: $0) }
    }

    static func installedZebraPrinters() -> [ZebraPrinter] {
        installedPrinters().filter { printer in
            printer.name.localizedCaseInsensitiveContains("zebra")
        }
    }
}
