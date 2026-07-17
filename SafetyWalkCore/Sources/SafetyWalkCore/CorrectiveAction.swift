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

    /// 효과확인 완료 = **완료 상태**에서 이행일·개선후위험도·확인자·확인시각·결과를 모두 갖춤
    /// (LEGAL_2_ARCH §1.1). 완료가 아닌데 효과확인 필드가 남아 있는 손상 레코드는 절대 완료로 읽지 않는다.
    public var isEffectivenessComplete: Bool {
        status == .completed
            && implementedAt != nil
            && postRiskLevel != nil
            && effectivenessResult != nil
            && effectivenessConfirmedAt != nil
            && !(confirmedBy ?? "").sw_isBlank
    }

    /// 종결 가능한 조치 = 효과확인 완료 AND 효과 있음(effective). 부분 효과·효과 없음 → false(미종결).
    public var isEffectivelyResolved: Bool {
        isEffectivenessComplete && effectivenessResult == .effective
    }

    /// 효과확인을 기록할 수 있는 상태 = 완료 + 이행일 + 개선후위험도. `CorrectiveActionEditing.confirmEffectiveness`
    /// 의 전제와 편집 화면의 버튼 활성화 조건이 공유하는 단일 소스(중복 제거).
    public var isReadyForEffectivenessCheck: Bool {
        status == .completed && implementedAt != nil && postRiskLevel != nil
    }

    /// 효과확인 불변조건 (SCHEMA_V3 §4.1): result·effectivenessConfirmedAt·confirmedBy 는
    /// **하나의 도메인 동작으로 함께 갱신** — 부분 갱신 금지. Core-only(`internal`): 전제 검증(이행일·
    /// 개선후위험도·확인자)과 원자 저장은 `CorrectiveActionEditing.confirmEffectiveness`가 담당하며,
    /// 앱 코드가 이 setter를 직접 호출해 전제를 우회하는 것을 막는다.
    func confirmEffectiveness(
        result: EffectivenessResult,
        by confirmedBy: String,
        at date: Date = Date()
    ) {
        self.effectivenessResult = result
        self.confirmedBy = confirmedBy
        self.effectivenessConfirmedAt = date
    }

    // MARK: - Core-only mutation (WO LEGAL-2c — routed through CorrectiveActionEditing)

    /// Applies edited fields under the STATUS-DRIVEN lifecycle:
    /// - 이행일·개선후위험도는 **.completed 전용** — 상태가 완료가 아니면 nil로 정규화한다(상태와 이행일이
    ///   모순된 값을 만들 수 없다). 완료를 벗어나면 두 필드가 함께 초기화된다.
    /// - 효과확인은 **완료를 벗어나거나** 실질 필드(measure/status/이행일/개선후위험도)가 바뀌면 초기화된다
    ///   (효과확인 무효화). responsibleName·dueDate·evidence는 비실질(효과확인 유지).
    /// `.completed` 인데 `implementedAt`이 없는 조합은 op(`CorrectiveActionEditing.update`)가 먼저 막는다.
    func applyFields(
        measure: String?, responsibleName: String?, dueDate: Date?,
        status: CorrectiveActionStatus, implementedAt: Date?,
        postRiskLevel: RiskLevel?, evidencePhotoData: Data?
    ) {
        let normImplementedAt = (status == .completed) ? implementedAt : nil
        let normPostRiskLevel = (status == .completed) ? postRiskLevel : nil
        let substantiveChanged = self.measure != measure
            || self.status != status
            || self.implementedAt != normImplementedAt
            || self.postRiskLevel != normPostRiskLevel
        self.measure = measure
        self.responsibleName = responsibleName
        self.dueDate = dueDate
        self.status = status
        self.implementedAt = normImplementedAt
        self.postRiskLevel = normPostRiskLevel
        self.evidencePhotoData = evidencePhotoData
        if isEffectivenessConfirmed && (status != .completed || substantiveChanged) {
            resetEffectiveness()
        }
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
