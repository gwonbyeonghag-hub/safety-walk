import Foundation
import SwiftData

@Model
public final class Inspection {
    public var id: UUID
    // Denormalized strings preserve history if the Site is later deleted
    public var siteId: UUID
    public var siteName: String
    public var areaId: UUID?
    public var areaName: String?
    public var inspectorName: String
    public var startedAt: Date
    public var completedAt: Date?
    public var status: InspectionStatus
    public var templateId: String
    @Relationship(deleteRule: .cascade) public var items: [ChecklistItem]
    @Relationship(deleteRule: .cascade) public var hazards: [Hazard]

    public init(
        siteId: UUID,
        siteName: String,
        areaId: UUID? = nil,
        areaName: String? = nil,
        inspectorName: String,
        templateId: String
    ) {
        self.id = UUID()
        self.siteId = siteId
        self.siteName = siteName
        self.areaId = areaId
        self.areaName = areaName
        self.inspectorName = inspectorName
        self.startedAt = Date()
        self.completedAt = nil
        self.status = .inProgress
        self.templateId = templateId
        self.items = []
        self.hazards = []
    }
}
