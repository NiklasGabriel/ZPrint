import Foundation

struct PrintSettings: Codable, Hashable {
    var lastPrinterName: String
    var copiesPerNumber: Int
    var startNumber: Int
    var endNumber: Int
    var numberFormat: String

    init(
        lastPrinterName: String = "",
        copiesPerNumber: Int = 1,
        startNumber: Int = 1,
        endNumber: Int = 1,
        numberFormat: String = "00000"
    ) {
        self.lastPrinterName = lastPrinterName
        self.copiesPerNumber = max(1, copiesPerNumber)
        self.startNumber = startNumber
        self.endNumber = endNumber
        self.numberFormat = numberFormat
    }
}
