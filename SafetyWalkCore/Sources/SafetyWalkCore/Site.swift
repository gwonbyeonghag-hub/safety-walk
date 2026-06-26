import Foundation
import SwiftData

@Model
public final class Site {
    public var id: UUID
    public var name: String
    public var address: String?
    public var createdAt: Date
    @Relationship(deleteRule: .cascade) public var areas: [Area]

    public init(name: String, address: String? = nil) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.createdAt = Date()
        self.areas = []
    }
}
