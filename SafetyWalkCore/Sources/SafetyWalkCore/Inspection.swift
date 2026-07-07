import Foundation
import SwiftData

@Model
public final class Inspection {
    public var id: UUID = UUID()
    // Denormalized strings preserve history if the Site is later deleted
    public var siteId: UUID = UUID()
    public var siteName: String = ""
    public var areaId: UUID?
    public var areaName: String?
    public var inspectorName: String = ""
    public var startedAt: Date = Date()
    public var completedAt: Date?
    public var status: InspectionStatus = InspectionStatus.inProgress
    public var templateId: String = ""
    // CloudKit requires every relationship to declare an inverse.
    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.inspection) public var items: [ChecklistItem]?
    @Relationship(deleteRule: .cascade, inverse: \Hazard.inspection) public var hazards: [Hazard]?

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
