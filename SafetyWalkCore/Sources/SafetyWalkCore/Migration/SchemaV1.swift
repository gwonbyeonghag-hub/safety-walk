import Foundation
import SwiftData

/// Frozen snapshot of the pre-CloudKit (WO-2b) on-disk schema — migration source only,
/// never used directly by app code. Every model is redeclared here because CloudKit
/// requires every relationship to declare an inverse (a runtime-discovered constraint,
/// not just "relationships must be optional"): `Site.areas`, `Inspection.items`,
/// `Inspection.hazards`, and `RiskAssessment.items` all gained an `inverse:` in
/// `SchemaV2`, which means their destination model (`Area`, `ChecklistItem`, `Hazard`,
/// `RiskAssessmentItem`) gained a new back-reference property — so every model in the
/// graph differs between V1 and V2, even fields untouched by WO-3's own retrofit.
/// `ChecklistItem`/`Hazard` additionally still carry `photoPath` (pre-`photoData`).
public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Site.self, Area.self, Inspection.self, ChecklistItem.self, Hazard.self,
         RiskAssessment.self, RiskAssessmentItem.self]
    }

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

    @Model
    public final class Area {
        public var id: UUID
        public var name: String
        public var siteId: UUID

        public init(name: String, siteId: UUID) {
            self.id = UUID()
            self.name = name
            self.siteId = siteId
        }
    }

    @Model
    public final class Inspection {
        public var id: UUID
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

    @Model
    public final class ChecklistItem {
        public var id: UUID
        public var inspectionId: UUID
        public var templateItemId: String
        public var title: String
        public var category: String
        public var result: ChecklistItemResult
        public var note: String?
        public var photoPath: String?
        public var linkedHazardId: UUID?
        public var sortOrder: Int

        public init(
            inspectionId: UUID,
            templateItemId: String,
            title: String,
            category: String,
            sortOrder: Int
        ) {
            self.id = UUID()
            self.inspectionId = inspectionId
            self.templateItemId = templateItemId
            self.title = title
            self.category = category
            self.result = .unchecked
            self.sortOrder = sortOrder
        }
    }

    @Model
    public final class Hazard {
        public var id: UUID
        public var inspectionId: UUID?
        public var siteId: UUID
        public var location: String
        public var type: HazardType
        public var riskLevel: RiskLevel
        public var hazardDescription: String
        public var photoPath: String
        public var correctiveActionStatus: CorrectiveActionStatus
        public var createdAt: Date
        public var updatedAt: Date

        public init(
            siteId: UUID,
            location: String,
            type: HazardType,
            riskLevel: RiskLevel,
            hazardDescription: String,
            photoPath: String,
            inspectionId: UUID? = nil
        ) {
            self.id = UUID()
            self.siteId = siteId
            self.location = location
            self.type = type
            self.riskLevel = riskLevel
            self.hazardDescription = hazardDescription
            self.photoPath = photoPath
            self.correctiveActionStatus = .notStarted
            self.createdAt = Date()
            self.updatedAt = Date()
            self.inspectionId = inspectionId
        }
    }

    // RiskAssessment/RiskAssessmentItem were already CloudKit-defaulted+optional since
    // WO-2 — this mirrors that exact pre-WO-3 shape, before the new inverse was added.
    @Model
    public final class RiskAssessment {
        public var id: UUID = UUID()
        public var kind: RiskAssessmentKind = RiskAssessmentKind.regular
        public var method: RiskAssessmentMethod = RiskAssessmentMethod.frequencySeverity
        public var siteId: UUID?
        public var siteName: String = ""
        public var assessorName: String = ""
        public var assessedAt: Date = Date()
        public var note: String?
        public var linkedInspectionId: UUID?
        @Relationship(deleteRule: .cascade) public var items: [RiskAssessmentItem]?

        public init(
            kind: RiskAssessmentKind = .regular,
            method: RiskAssessmentMethod = .frequencySeverity,
            siteId: UUID? = nil,
            siteName: String = "",
            assessorName: String = "",
            note: String? = nil,
            linkedInspectionId: UUID? = nil
        ) {
            self.id = UUID()
            self.kind = kind
            self.method = method
            self.siteId = siteId
            self.siteName = siteName
            self.assessorName = assessorName
            self.assessedAt = Date()
            self.note = note
            self.linkedInspectionId = linkedInspectionId
            self.items = []
        }
    }

    @Model
    public final class RiskAssessmentItem {
        public var id: UUID = UUID()
        public var taskDescription: String = ""
        public var hazardDescription: String = ""
        public var currentControls: String?
        public var likelihood: Int?
        public var severity: Int?
        public var riskLevel: RiskLevel = RiskLevel.low
        public var reductionMeasure: String?
        public var postRiskLevel: RiskLevel?
        public var responsibleName: String?
        public var dueDate: Date?
        public var correctiveActionStatus: CorrectiveActionStatus = CorrectiveActionStatus.notStarted
        public var linkedHazardId: UUID?
        public var sortOrder: Int = 0

        public init(
            taskDescription: String = "",
            hazardDescription: String = "",
            currentControls: String? = nil,
            likelihood: Int? = nil,
            severity: Int? = nil,
            riskLevel: RiskLevel = .low,
            reductionMeasure: String? = nil,
            postRiskLevel: RiskLevel? = nil,
            responsibleName: String? = nil,
            dueDate: Date? = nil,
            correctiveActionStatus: CorrectiveActionStatus = .notStarted,
            linkedHazardId: UUID? = nil,
            sortOrder: Int = 0
        ) {
            self.id = UUID()
            self.taskDescription = taskDescription
            self.hazardDescription = hazardDescription
            self.currentControls = currentControls
            self.likelihood = likelihood
            self.severity = severity
            self.riskLevel = riskLevel
            self.reductionMeasure = reductionMeasure
            self.postRiskLevel = postRiskLevel
            self.responsibleName = responsibleName
            self.dueDate = dueDate
            self.correctiveActionStatus = correctiveActionStatus
            self.linkedHazardId = linkedHazardId
            self.sortOrder = sortOrder
        }
    }
}
