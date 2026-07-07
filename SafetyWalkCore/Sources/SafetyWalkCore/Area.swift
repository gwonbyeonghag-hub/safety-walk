import Foundation
import SwiftData

@Model
public final class Area {
    public var id: UUID = UUID()
    public var name: String = ""
    // Stored as UUID so deletion of a Site does not cascade-wipe inspection history
    public var siteId: UUID = UUID()
    // CloudKit-required inverse of Site.areas (§ SWIFTDATA_MIGRATION.md). Not read by
    // app code — `siteId` above remains the source of truth for lookups; this exists
    // only to satisfy CloudKit's "every relationship needs an inverse" constraint.
    public var site: Site?

    public init(name: String, siteId: UUID) {
        self.id = UUID()
        self.name = name
        self.siteId = siteId
    }
}
