import Foundation
import SwiftData

/// 비TBM 공유 증명 (SCHEMA_V3 §4) — 교육/게시/서면/전자 공유 기록. TBM 공유는 별도
/// `SafetyBriefing`(LEGAL_2_ARCH §3 이중 저장 제거). `phase`/`method`/`sharedAt` are stored
/// optional (CloudKit) but REQUIRED at construction — **nil은 미설정을 의미**(교정 #3).
///
/// This `@Model` body is a pure DATA container, exactly like `CorrectiveAction` (WO LEGAL-2c):
/// stored properties + an `internal` data initializer that validates nothing. Every WO LEGAL-2d
/// rule — 비공백 대상·담당자, 시점(사전=planned/사후=finalized) 게이트, 버전형 스냅샷 생성,
/// 최신성 판정 — lives in `SharingEventPolicy` / `SharingEventRecording`, never in this body.
///
/// **생성 즉시 불변**(SCHEMA_V3 §7): the initializer is deliberately not `public`, so outside the
/// package a `SharingEvent` can only come from `SharingEventRecording.record` — and there is no
/// update/delete op at all, because a past 공유 사실 is not editable. Multiple real shares are
/// legitimate, so nothing dedupes or uniques them (CloudKit forbids `.unique` anyway).
@Model
public final class SharingEvent {
    public var id: UUID = UUID()
    public private(set) var phase: SharingPhase?           // nil=미설정(교정 #3)
    public private(set) var method: SharingMethod?
    public private(set) var sharedAt: Date?
    public private(set) var target: String?
    public private(set) var contentSnapshot: String = ""
    public private(set) var ownerName: String?
    // CloudKit-required inverse of RiskAssessment.sharingEvents.
    public var riskAssessment: RiskAssessment?

    /// Plain data initializer — assigns the given values and nothing else. SCHEMA_V3 §4.1 생성자
    /// 계약: phase·method·sharedAt are REQUIRED; WO LEGAL-2d additionally makes target·ownerName·
    /// contentSnapshot required, so a business-empty 공유 기록 cannot even be constructed. All
    /// validation belongs to `SharingEventRecording.record`, the single create gate.
    convenience init(
        phase: SharingPhase,
        method: SharingMethod,
        sharedAt: Date,
        target: String,
        contentSnapshot: String,
        ownerName: String
    ) {
        self.init(corruptedPhase: phase, method: method, sharedAt: sharedAt,
                  target: target, contentSnapshot: contentSnapshot, ownerName: ownerName)
    }

    /// Corruption seam — **Core-internal, tests only.** CloudKit stores every attribute as optional and
    /// can deliver a partially-populated record (an older client, an interrupted sync, a hand-edited
    /// store), so the completeness rules in `SharingEventPolicy` must be provable against records the
    /// sanctioned create gate would never produce. This initializer is the only way to build one, it is
    /// not `public`, and it weakens neither the public immutability nor the schema.
    init(corruptedPhase phase: SharingPhase?, method: SharingMethod?, sharedAt: Date?,
         target: String?, contentSnapshot: String, ownerName: String?) {
        self.id = UUID()
        self.phase = phase
        self.method = method
        self.sharedAt = sharedAt
        self.target = target
        self.contentSnapshot = contentSnapshot
        self.ownerName = ownerName
    }

    /// 업무상 완전한 공유 기록인지 (SCHEMA_V3 §4.1 + WO LEGAL-2d 반송 1차 P1-B). 시점·방법·시각이 있고
    /// 대상·담당자·스냅샷이 비어 있지 않아야 한다 — `SharingEventPolicy` 의 completeness 판정과 **같은
    /// 계약**이며, 저장 직전 방어선이다.
    public func validate() throws {
        guard phase != nil else { throw ModelValidationError.missingPhase }
        guard method != nil else { throw ModelValidationError.missingMethod }
        guard sharedAt != nil else { throw ModelValidationError.missingSharedAt }
        guard !(target ?? "").sw_isBlank else { throw ModelValidationError.emptyTarget }
        guard !(ownerName ?? "").sw_isBlank else { throw ModelValidationError.emptyOwnerName }
        guard !contentSnapshot.sw_isBlank else { throw ModelValidationError.emptyContentSnapshot }
    }
}
