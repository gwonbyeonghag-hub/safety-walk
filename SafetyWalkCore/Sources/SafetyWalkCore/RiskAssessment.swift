import Foundation
import SwiftData

/// 위험성평가 (Risk Assessment) — one assessment record (평가표).
/// CloudKit-ready: every attribute is optional or has a default value; the
/// to-many relationship is optional; no `@Attribute(.unique)`. (V2_ROADMAP AD-3)
@Model
public final class RiskAssessment {
    public var id: UUID = UUID()
    public var kind: RiskAssessmentKind = RiskAssessmentKind.regular
    public var method: RiskAssessmentMethod = RiskAssessmentMethod.frequencySeverity
    public var siteId: UUID?
    // Denormalized so the record survives if the Site is later deleted (Inspection pattern)
    public var siteName: String = ""
    public var assessorName: String = ""
    public var assessedAt: Date = Date()
    public var note: String?
    public var linkedInspectionId: UUID?
    // CloudKit requires every relationship to declare an inverse.
    @Relationship(deleteRule: .cascade, inverse: \RiskAssessmentItem.riskAssessment) public var items: [RiskAssessmentItem]?

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
