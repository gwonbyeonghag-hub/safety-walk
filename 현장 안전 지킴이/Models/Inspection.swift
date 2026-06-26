import Foundation
import SwiftData

@Model
final class Inspection {
    var id: UUID
    // Denormalized strings preserve history if the Site is later deleted
    var siteId: UUID
    var siteName: String
    var areaId: UUID?
    var areaName: String?
    var inspectorName: String
    var startedAt: Date
    var completedAt: Date?
    var status: InspectionStatus
    var templateId: String
    @Relationship(deleteRule: .cascade) var items: [ChecklistItem]
    @Relationship(deleteRule: .cascade) var hazards: [Hazard]

    init(
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
