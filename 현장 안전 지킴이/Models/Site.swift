import Foundation
import SwiftData

@Model
final class Site {
    var id: UUID
    var name: String
    var address: String?
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var areas: [Area]

    init(name: String, address: String? = nil) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.createdAt = Date()
        self.areas = []
    }
}
