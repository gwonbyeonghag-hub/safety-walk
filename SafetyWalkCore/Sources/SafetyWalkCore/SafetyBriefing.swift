import Foundation
import SwiftData

/// TBM 안전브리핑 = TBM 공유 증명 (SCHEMA_V3 §4). References Site/Program/Assessment/Area by
/// UUID (관계 아님 → 상위 삭제에도 생존). content/snapshots lock at `conducted`,
/// participants/서명 lock at `finalized`. `retainUntil` is a policy-driven date — 자동 판정
/// 안 함(교정). CloudKit-ready: attributes optional or defaulted, relationships optional with
/// inverse, no `.unique`.
///
/// WO LEGAL-TBM-1 §5 봉인: `status`/`conductedAt`/`finalizedAt`/`cancelledAt` 는 `internal(set)`
/// — 수명주기 전환은 `BriefingLifecycle`(conduct/finalize/cancel)만 소유한다. `public init` 에
/// `status` 인자가 없어 모든 브리핑은 항상 `.draft` 로 태어난다(아래 참고).
@Model
public final class SafetyBriefing {
    public var id: UUID = UUID()
    public var siteId: UUID?
    public var siteName: String = ""
    public var programId: UUID?
    public var assessmentId: UUID?
    public var areaId: UUID?
    public var briefingProfile: BriefingProfileCode?   // 프로필 코드(교정 #6)
    public var taskDescription: String = ""
    public var occurredAt: Date?
    public var location: String = ""
    public internal(set) var status: BriefingStatus = BriefingStatus.draft
    public var briefingContent: String = ""
    public var ownerName: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public internal(set) var conductedAt: Date?
    public internal(set) var finalizedAt: Date?
    public internal(set) var cancelledAt: Date?
    public var cancellationReason: String?
    public var retainUntil: Date?                       // 정책 기반, 자동 판정 안 함
    public var supersedesBriefingId: UUID?
    public var correctionReason: String?
    public var correctedAt: Date?
    public var correctedBy: String?
    // CloudKit requires every relationship to declare an inverse.
    @Relationship(deleteRule: .cascade, inverse: \BriefingParticipant.briefing) public var participants: [BriefingParticipant]?
    @Relationship(deleteRule: .cascade, inverse: \BriefingRiskItemSnapshot.briefing) public var riskSnapshots: [BriefingRiskItemSnapshot]?

    /// SCHEMA_V3 §4.1 생성자 계약: siteId·siteName are REQUIRED.
    public init(
        siteId: UUID,
        siteName: String,
        programId: UUID? = nil,
        assessmentId: UUID? = nil,
        areaId: UUID? = nil,
        briefingProfile: BriefingProfileCode? = nil,
        taskDescription: String = "",
        occurredAt: Date? = nil,
        location: String = "",
        ownerName: String? = nil
    ) {
        self.id = UUID()
        self.siteId = siteId
        self.siteName = siteName
        self.programId = programId
        self.assessmentId = assessmentId
        self.areaId = areaId
        self.briefingProfile = briefingProfile
        self.taskDescription = taskDescription
        self.occurredAt = occurredAt
        self.location = location
        self.ownerName = ownerName
        self.createdAt = Date()
        self.updatedAt = Date()
        self.participants = []
        self.riskSnapshots = []
    }

    public func validate() throws {
        guard siteId != nil else { throw ModelValidationError.missingSite }
        guard !siteName.sw_isBlank else { throw ModelValidationError.emptySiteName }
    }
}
