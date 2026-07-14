import Foundation
import SwiftData

/// 위험성평가 (Risk Assessment) — independent root record (SCHEMA_V3 §4). Every legacy field
/// is preserved (교정 #4); V3 adds the planned→inProgress→finalized lifecycle, program
/// reference + value snapshots (관계 아님 → cascade 없음), audit/cancel timestamps, and the
/// 근로자대표 status. CloudKit-ready: attributes optional or defaulted, relationships optional
/// with an explicit inverse, no `@Attribute(.unique)`.
@Model
public final class RiskAssessment {
    public var id: UUID = UUID()
    public var kind: RiskAssessmentKind = RiskAssessmentKind.regular
    public var method: RiskAssessmentMethod = RiskAssessmentMethod.frequencySeverity
    public var siteId: UUID?
    // Denormalized so the record survives if the Site is later deleted (Inspection pattern)
    public var siteName: String = ""
    public var assessorName: String = ""       // ★보존 — 법정 담당자·PDF·Mac·상세
    public var linkedInspectionId: UUID?       // ★보존 — 체크리스트법 진입
    public var note: String?
    // 신규: 프로그램 참조 + 값 코드 스냅샷 (관계 아님 → cascade 없음, 생존)
    public var programId: UUID?
    public var jurisdictionSnapshot: JurisdictionCode?
    public var industryProfileSnapshot: IndustryProfileCode?
    public var programVersionSnapshot: Int = 0
    // 상태·감사·취소 시각 (교정 #5·#6)
    public var status: AssessmentStatus = AssessmentStatus.planned
    public var scheduledAt: Date?
    public var assessedAt: Date?
    public var finalizedAt: Date?
    public var cancelledAt: Date?
    public var cancellationReason: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var workerRepStatus: WorkerRepStatus?   // nil=미기록(교정 #3)
    // CloudKit requires every relationship to declare an inverse.
    @Relationship(deleteRule: .cascade, inverse: \AssessmentCriteria.riskAssessment) public var criteria: AssessmentCriteria?
    @Relationship(deleteRule: .cascade, inverse: \RiskAssessmentItem.riskAssessment) public var items: [RiskAssessmentItem]?
    @Relationship(deleteRule: .cascade, inverse: \RiskAssessmentParticipant.riskAssessment) public var participants: [RiskAssessmentParticipant]?
    @Relationship(deleteRule: .cascade, inverse: \SharingEvent.riskAssessment) public var sharingEvents: [SharingEvent]?

    /// SCHEMA_V3 §4.1 생성자 계약: siteId·siteName·kind·method are REQUIRED (no init default),
    /// even though the stored properties keep CloudKit defaults. `validate()` re-checks the
    /// runtime rules (non-blank siteName) before persistence.
    public init(
        kind: RiskAssessmentKind,
        method: RiskAssessmentMethod,
        siteId: UUID,
        siteName: String,
        assessorName: String = "",
        note: String? = nil,
        linkedInspectionId: UUID? = nil,
        programId: UUID? = nil,
        jurisdictionSnapshot: JurisdictionCode? = nil,
        industryProfileSnapshot: IndustryProfileCode? = nil,
        programVersionSnapshot: Int = 0,
        status: AssessmentStatus = .planned,
        scheduledAt: Date? = nil,
        workerRepStatus: WorkerRepStatus? = nil
    ) {
        self.id = UUID()
        self.kind = kind
        self.method = method
        self.siteId = siteId
        self.siteName = siteName
        self.assessorName = assessorName
        self.note = note
        self.linkedInspectionId = linkedInspectionId
        self.programId = programId
        self.jurisdictionSnapshot = jurisdictionSnapshot
        self.industryProfileSnapshot = industryProfileSnapshot
        self.programVersionSnapshot = programVersionSnapshot
        self.status = status
        self.scheduledAt = scheduledAt
        self.workerRepStatus = workerRepStatus
        self.createdAt = Date()
        self.updatedAt = Date()
        self.items = []
        self.participants = []
        self.sharingEvents = []
    }

    /// Blocks persisting a business-empty assessment (SCHEMA_V3 §4.1).
    public func validate() throws {
        guard siteId != nil else { throw ModelValidationError.missingSite }
        guard !siteName.sw_isBlank else { throw ModelValidationError.emptySiteName }
    }
}
