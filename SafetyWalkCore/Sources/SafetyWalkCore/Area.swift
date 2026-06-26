import Foundation
import SwiftData

@Model
public final class Area {
    public var id: UUID
    public var name: String
    // Stored as UUID so deletion of a Site does not cascade-wipe inspection history
    public var siteId: UUID

    public init(name: String, siteId: UUID) {
        self.id = UUID()
        self.name = name
        self.siteId = siteId
    }
}
