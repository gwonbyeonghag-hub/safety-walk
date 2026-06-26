import Foundation
import SwiftData

@Model
final class Area {
    var id: UUID
    var name: String
    // Stored as UUID so deletion of a Site does not cascade-wipe inspection history
    var siteId: UUID

    init(name: String, siteId: UUID) {
        self.id = UUID()
        self.name = name
        self.siteId = siteId
    }
}
