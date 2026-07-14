import Foundation
import SwiftData

/// 비TBM 공유 증명 (SCHEMA_V3 §4) — 교육/게시/서면/전자 공유 기록. TBM 공유는 별도
/// `SafetyBriefing`. Immutable the moment it is created. `phase`/`method`/`sharedAt` are
/// stored optional (CloudKit) but REQUIRED at construction — **nil은 미설정을 의미**(교정 #3).
/// CloudKit-ready.
@Model
public final class SharingEvent {
    public var id: UUID = UUID()
    public var phase: SharingPhase?           // nil=미설정(교정 #3)
    public var method: SharingMethod?
    public var sharedAt: Date?
    public var target: String?
    public var contentSnapshot: String = ""
    public var ownerName: String?
    // CloudKit-required inverse of RiskAssessment.sharingEvents.
    public var riskAssessment: RiskAssessment?

    /// SCHEMA_V3 §4.1 생성자 계약: phase·method·sharedAt are REQUIRED.
    public init(
        phase: SharingPhase,
        method: SharingMethod,
        sharedAt: Date,
        target: String? = nil,
        contentSnapshot: String = "",
        ownerName: String? = nil
    ) {
        self.id = UUID()
        self.phase = phase
        self.method = method
        self.sharedAt = sharedAt
        self.target = target
        self.contentSnapshot = contentSnapshot
        self.ownerName = ownerName
    }

    public func validate() throws {
        guard phase != nil else { throw ModelValidationError.missingPhase }
        guard method != nil else { throw ModelValidationError.missingMethod }
        guard sharedAt != nil else { throw ModelValidationError.missingSharedAt }
    }
}
