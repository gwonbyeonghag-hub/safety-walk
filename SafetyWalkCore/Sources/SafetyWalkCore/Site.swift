import Foundation
import SwiftData

@Model
public final class Site {
    public var id: UUID = UUID()
    public var name: String = ""
    public var address: String?
    public var createdAt: Date = Date()
    // CloudKit requires every relationship to declare an inverse (Area.site).
    @Relationship(deleteRule: .cascade, inverse: \Area.site) public var areas: [Area]?

    public init(name: String, address: String? = nil) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.createdAt = Date()
        self.areas = []
    }
}
