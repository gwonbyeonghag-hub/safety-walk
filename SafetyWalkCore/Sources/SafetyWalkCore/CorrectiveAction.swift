import Foundation
import SwiftData

/// 개선(감소)대책 — one corrective action under a `RiskAssessmentItem` (SCHEMA_V3 §4). Absorbs
/// the old per-item improvement fields (measure/responsible/due/status/postRiskLevel) and adds
/// 효과확인. `isRequired` is NOT stored — it is derived from the parent item's 초과 여부
/// (교정 #2). 효과확인 결과는 Bool이 아니라 `effectivenessResult`(nil=미확인). CloudKit-ready.
///
/// WO LEGAL-2c: the mutable value fields + the 효과확인 triplet are `internal(set)` — external
/// (app) code creates an action through `init`, but every later edit goes through the Core ops
/// in `CorrectiveActionEditing`, which validate (빈 조치 차단), persist atomically, and reset the
/// 효과확인 when a substantive field changes (효과확인 무효화). SwiftData stored type/default is
/// unchanged (no schema-field change — access control only).
@Model
public final class CorrectiveAction {
    public var id: UUID = UUID()
    public internal(set) var measure: String?
    public internal(set) var responsibleName: String?
    public internal(set) var dueDate: Date?
    public internal(set) var status: CorrectiveActionStatus = CorrectiveActionStatus.notStarted
    public internal(set) var implementedAt: Date?                 // 이행일
    public internal(set) var confirmedBy: String?                 // 효과 확인자
    public internal(set) var effectivenessConfirmedAt: Date?      // 감사 시각(교정 #6)
    public internal(set) var effectivenessResult: EffectivenessResult?  // nil=미확인(교정 #2)
    @Attribute(.externalStorage) public internal(set) var evidencePhotoData: Data?
    public internal(set) var postRiskLevel: RiskLevel?           // 개선 후 위험성
    // CloudKit-required inverse of RiskAssessmentItem.correctiveActions.
    public var item: RiskAssessmentItem?

    /// SCHEMA_V3 §4.1 생성자 계약: `item` connection is REQUIRED. `isRequired` is neither a
    /// stored field nor an init arg — it is derived from the parent item's 초과 여부.
    public init(
        item: RiskAssessmentItem,
        measure: String? = nil,
        responsibleName: String? = nil,
        dueDate: Date? = nil,
        status: CorrectiveActionStatus = .notStarted,
        postRiskLevel: RiskLevel? = nil
    ) {
        self.id = UUID()
        self.item = item
        self.measure = measure
        self.responsibleName = responsibleName
        self.dueDate = dueDate
        self.status = status
        self.postRiskLevel = postRiskLevel
    }

    /// 저장 안 함 → 부모 item.criteriaDecision == exceedsThreshold 에서 파생(교정 #2).
    public var isRequired: Bool {
        item?.criteriaDecision == .exceedsThreshold
    }

    /// "효과확인됨"은 result≠nil로 파생 (Bool 제거, 교정 #2).
    public var isEffectivenessConfirmed: Bool {
        effectivenessResult != nil
    }

    /// 효과확인 완료 = 이행일·개선후위험도·확인자 기록 + 결과 확정 (LEGAL_2_ARCH §1.1). result≠nil 만으로는
    /// "확인만"이고, 완료는 이행 근거(이행일·개선후위험도)와 확인자까지 갖춰야 한다.
    public var isEffectivenessComplete: Bool {
        implementedAt != nil
            && postRiskLevel != nil
            && effectivenessResult != nil
            && !(confirmedBy ?? "").sw_isBlank
    }

    /// 종결 가능한 조치 = 효과확인 완료 AND 효과 있음(effective). 부분 효과·효과 없음 → false(미종결).
    public var isEffectivelyResolved: Bool {
        isEffectivenessComplete && effectivenessResult == .effective
    }

    /// 빈 개선조치 저장 금지 (WO LEGAL-2c): 감소대책(measure)이 공백이면 저장 불가. LEGAL-0의
    /// save()-throws / SCHEMA_V3 §4.1 "insert 전 검증 실패 시 저장 금지" 패턴 확장.
    public func validate() throws {
        guard !(measure ?? "").sw_isBlank else { throw CorrectiveActionError.emptyMeasure }
    }

    /// 효과확인 불변조건 (SCHEMA_V3 §4.1): result·effectivenessConfirmedAt·confirmedBy 는
    /// **하나의 도메인 동작으로 함께 갱신** — 부분 갱신 금지. 개별 setter 대신 항상 이 함수로.
    /// (전제 검증·원자 저장은 `CorrectiveActionEditing.confirmEffectiveness` 가 담당.)
    public func confirmEffectiveness(
        result: EffectivenessResult,
        by confirmedBy: String,
        at date: Date = Date()
    ) {
        self.effectivenessResult = result
        self.confirmedBy = confirmedBy
        self.effectivenessConfirmedAt = date
    }

    // MARK: - Core-only mutation (WO LEGAL-2c — routed through CorrectiveActionEditing)

    /// Applies edited fields. If a SUBSTANTIVE field (measure/status/implementedAt/postRiskLevel)
    /// changes while a 효과확인 was recorded, the 효과확인 triplet is reset (효과확인 무효화) — the prior
    /// confirmation was about the old measure/result and is now stale. responsibleName·dueDate·
    /// evidence are non-substantive (they don't change what was done or its effect).
    func applyFields(
        measure: String?, responsibleName: String?, dueDate: Date?,
        status: CorrectiveActionStatus, implementedAt: Date?,
        postRiskLevel: RiskLevel?, evidencePhotoData: Data?
    ) {
        let substantiveChanged = self.measure != measure
            || self.status != status
            || self.implementedAt != implementedAt
            || self.postRiskLevel != postRiskLevel
        self.measure = measure
        self.responsibleName = responsibleName
        self.dueDate = dueDate
        self.status = status
        self.implementedAt = implementedAt
        self.postRiskLevel = postRiskLevel
        self.evidencePhotoData = evidencePhotoData
        if substantiveChanged && isEffectivenessConfirmed { resetEffectiveness() }
    }

    /// Clears the 효과확인 triplet (Core-only) — back to 미확인.
    func resetEffectiveness() {
        effectivenessResult = nil
        confirmedBy = nil
        effectivenessConfirmedAt = nil
    }

    /// Restores the 효과확인 triplet verbatim — used to undo a failed commit in memory.
    func restoreEffectiveness(result: EffectivenessResult?, by person: String?, at date: Date?) {
        effectivenessResult = result
        confirmedBy = person
        effectivenessConfirmedAt = date
    }

    /// A verbatim snapshot of every mutable field — captured before an edit so a failed commit can
    /// be undone in memory (`context.rollback()` reverts the store but leaves the instance dirty).
    struct FieldSnapshot {
        let measure: String?
        let responsibleName: String?
        let dueDate: Date?
        let status: CorrectiveActionStatus
        let implementedAt: Date?
        let postRiskLevel: RiskLevel?
        let evidencePhotoData: Data?
        let effectivenessResult: EffectivenessResult?
        let confirmedBy: String?
        let effectivenessConfirmedAt: Date?
    }

    func snapshotFields() -> FieldSnapshot {
        FieldSnapshot(
            measure: measure, responsibleName: responsibleName, dueDate: dueDate,
            status: status, implementedAt: implementedAt, postRiskLevel: postRiskLevel,
            evidencePhotoData: evidencePhotoData,
            effectivenessResult: effectivenessResult, confirmedBy: confirmedBy,
            effectivenessConfirmedAt: effectivenessConfirmedAt)
    }

    func restoreFields(_ s: FieldSnapshot) {
        measure = s.measure
        responsibleName = s.responsibleName
        dueDate = s.dueDate
        status = s.status
        implementedAt = s.implementedAt
        postRiskLevel = s.postRiskLevel
        evidencePhotoData = s.evidencePhotoData
        effectivenessResult = s.effectivenessResult
        confirmedBy = s.confirmedBy
        effectivenessConfirmedAt = s.effectivenessConfirmedAt
    }
}
