import Foundation

/// WO LEGAL-2c lifecycle/mutation policy for `CorrectiveAction`, kept OUT of the `@Model` body so the
/// model stays a data container. Derived predicates are `public` (read by app/reports/VM); the
/// mutation helpers are `internal` (used only by the `CorrectiveActionEditing` ops in this module).
public extension CorrectiveAction {

    /// 효과확인 완료 = **완료 상태**에서 이행일·개선후위험도·확인자·확인시각·결과를 모두 갖춤
    /// (LEGAL_2_ARCH §1.1). 완료가 아닌데 효과확인 필드가 남아 있는 손상 레코드는 절대 완료로 읽지 않는다.
    var isEffectivenessComplete: Bool {
        status == .completed
            && implementedAt != nil
            && postRiskLevel != nil
            && effectivenessResult != nil
            && effectivenessConfirmedAt != nil
            && !(confirmedBy ?? "").sw_isBlank
    }

    /// 종결 가능한 조치 = 효과확인 완료 AND 효과 있음(effective). 부분·없음 → false(미종결).
    var isEffectivelyResolved: Bool {
        isEffectivenessComplete && effectivenessResult == .effective
    }

    /// 효과확인을 기록할 수 있는 상태 = 완료 + 이행일 + 개선후위험도. op 전제와 편집 화면 버튼 활성화가
    /// 공유하는 단일 소스.
    var isReadyForEffectivenessCheck: Bool {
        status == .completed && implementedAt != nil && postRiskLevel != nil
    }
}

extension CorrectiveAction {

    /// A verbatim snapshot of every mutable field — captured before an edit so a failed commit can be
    /// undone in memory (`context.rollback()` reverts the store but leaves the instance dirty).
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

    /// Applies edited fields under the STATUS-DRIVEN lifecycle:
    /// - 이행일·개선후위험도는 **.completed 전용** — 완료가 아니면 nil로 정규화(상태·이행일 모순 차단).
    /// - 효과확인은 **완료를 벗어나거나** 실질 필드(measure/status/이행일/개선후위험도)가 바뀌면 초기화된다.
    ///   초기화는 `effectivenessResult != nil` 여부에 **의존하지 않는다** — confirmedBy/confirmedAt 만 남은
    ///   손상 상태여도 세 필드를 항상 함께 nil로 만든다. responsibleName·dueDate·evidence는 비실질.
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
        if status != .completed || substantiveChanged {
            resetEffectiveness()
        }
    }

    /// Clears the 효과확인 triplet (Core-only) — back to 미확인. Always sets all three together.
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
}
