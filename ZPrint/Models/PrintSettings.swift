import Foundation

struct PrintSettings: Codable, Hashable {
    var selectedPrinterName: String?
    var copies: Int
    var startNumber: Int
    var endNumber: Int

    init(selectedPrinterName: String? = nil, copies: Int = 1, startNumber: Int = 1, endNumber: Int = 1) {
        self.selectedPrinterName = selectedPrinterName
        self.copies = copies
        self.startNumber = startNumber
        self.endNumber = endNumber
    }
}
