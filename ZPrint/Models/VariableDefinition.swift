import Foundation

struct VariableDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var sampleValue: String

    init(id: UUID = UUID(), name: String, sampleValue: String = "") {
        self.id = id
        self.name = name
        self.sampleValue = sampleValue
    }
}
