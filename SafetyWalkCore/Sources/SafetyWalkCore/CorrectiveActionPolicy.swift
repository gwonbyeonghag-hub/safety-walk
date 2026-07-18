import Foundation

/// WO LEGAL-2c lifecycle/mutation policy for `CorrectiveAction` — an INDEPENDENT type (not a model
/// extension) so the `@Model` bodies of `CorrectiveAction`/`RiskAssessment`/`RiskAssessmentItem` stay
/// pure data containers. Pure judgement functions are `public static` (read by app/reports/VM/closure/
/// finalization); the mutation·snapshot·restore helpers are `internal static` (used only by the
/// `CorrectiveActionEditing` ops in this module, which own precondition checks + atomic persistence).
public enum CorrectiveActionPolicy {

    // MARK: - Create gate

    /// The ONLY way to bring a `CorrectiveAction` into existence outside this package (the model's own
    /// initializer is `internal`). Validates and returns a draft; it never **saves** — committing is the
    /// caller's job, or `CorrectiveActionEditing.add`'s when the assessment is already editable. (Note
    /// SwiftData registers the new object into `item`'s context on its own, via the relationship — the
    /// factory issues no `insert`, but the draft is not detached either.)
    ///
    /// Why a separate create gate exists (WO LEGAL-2c 5차): `add` is the atomic EDIT op and refuses a
    /// `.planned` assessment, but the 최초 작성 경로 (평가 생성 화면·Mac 시드) assembles items and their
    /// 개선조치 while the assessment is still `.planned`. That path needs the same validation without
    /// the editable-state precondition — this factory, not a direct model construction.
    ///
    /// Guarantees: 비공백 감소대책(공백만이면 `emptyMeasure`), 항상 `.notStarted`, 이행일·개선후위험도·
    /// 효과확인 3필드·증거사진은 전부 nil (the initializer takes no such parameters).
    public static func makeDraft(
        item: RiskAssessmentItem,
        measure: String,
        responsibleName: String? = nil,
        dueDate: Date? = nil
    ) throws -> CorrectiveAction {
        guard !measure.sw_isBlank else { throw CorrectiveActionError.emptyMeasure }
        return CorrectiveAction(item: item, measure: measure,
                                responsibleName: responsibleName, dueDate: dueDate)
    }

    // MARK: - Pure judgement (CorrectiveAction)

    /// 조치 필요 여부 = 부모 item.criteriaDecision == exceedsThreshold 에서 파생(저장 안 함, 교정 #2).
    public static func isRequired(_ action: CorrectiveAction) -> Bool {
        action.item?.criteriaDecision == .exceedsThreshold
    }

    /// "효과확인됨" = result≠nil 로 파생(교정 #2).
    public static func isEffectivenessConfirmed(_ action: CorrectiveAction) -> Bool {
        action.effectivenessResult != nil
    }

    /// 효과확인 완료 = **완료 상태**에서 이행일·개선후위험도·확인자·확인시각·결과를 모두 갖춤
    /// (LEGAL_2_ARCH §1.1). 완료가 아닌데 효과확인 필드가 남아 있는 손상 레코드는 절대 완료로 읽지 않는다.
    public static func isEffectivenessComplete(_ action: CorrectiveAction) -> Bool {
        action.status == .completed
            && action.implementedAt != nil
            && action.postRiskLevel != nil
            && action.effectivenessResult != nil
            && action.effectivenessConfirmedAt != nil
            && !(action.confirmedBy ?? "").sw_isBlank
    }

    /// 종결 가능한 조치 = 효과확인 완료 AND 효과 있음(effective). 부분·없음 → false(미종결).
    public static func isEffectivelyResolved(_ action: CorrectiveAction) -> Bool {
        isEffectivenessComplete(action) && action.effectivenessResult == .effective
    }

    /// 효과확인을 기록할 수 있는 상태 = 완료 + 이행일 + 개선후위험도. op 전제와 편집 화면 버튼 활성화가
    /// 공유하는 단일 소스.
    public static func isReadyForEffectivenessCheck(_ action: CorrectiveAction) -> Bool {
        action.status == .completed && action.implementedAt != nil && action.postRiskLevel != nil
    }

    // MARK: - Pure judgement (RiskAssessment / RiskAssessmentItem)

    /// 개선조치 편집 가능 상태 — inProgress에서 계획하고 finalized 후에도 수정 가능(LEGAL_2_ARCH §1);
    /// planned/cancelled는 불가. Core op와 두 화면이 공유하는 단일 규칙(상태 3중 중복 제거).
    public static func allowsCorrectiveActionEditing(_ assessment: RiskAssessment) -> Bool {
        assessment.status == .inProgress || assessment.status == .finalized
    }

    /// 기준 초과 항목인가 — 초과면 개선조치 계획이 필수(LEGAL_2_ARCH §1.1).
    public static func needsCorrectiveActionPlan(_ item: RiskAssessmentItem) -> Bool {
        item.criteriaDecision == .exceedsThreshold
    }

    /// 초과 항목이면 ≥1 개선조치(감소대책 비어있지 않은)가 있어야 계획 충족. 초과가 아니면 항상 충족.
    public static func hasRequiredCorrectiveActionPlan(_ item: RiskAssessmentItem) -> Bool {
        guard needsCorrectiveActionPlan(item) else { return true }
        return (item.correctiveActions ?? []).contains { !($0.measure ?? "").sw_isBlank }
    }

    /// 기준 초과인데 아직 개선조치 계획이 없는 상태 — 상세·목록 화면의 "계획 필요" 안내 단일 소스.
    public static func isMissingRequiredCorrectiveActionPlan(_ item: RiskAssessmentItem) -> Bool {
        needsCorrectiveActionPlan(item) && !hasRequiredCorrectiveActionPlan(item)
    }

    /// 1:N 개선조치를 결정적 순서로 반환 — CloudKit은 to-many 순서를 보장하지 않고 스키마에 sortOrder가
    /// 없으므로(동결) `id` 기준으로 안정 정렬한다. 화면·리포트가 같은 순서를 쓰도록 하는 단일 소스.
    public static func sortedCorrectiveActions(_ item: RiskAssessmentItem) -> [CorrectiveAction] {
        (item.correctiveActions ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
    }

    // MARK: - Core-only mutation / snapshot / restore

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

    static func snapshot(_ a: CorrectiveAction) -> FieldSnapshot {
        FieldSnapshot(
            measure: a.measure, responsibleName: a.responsibleName, dueDate: a.dueDate,
            status: a.status, implementedAt: a.implementedAt, postRiskLevel: a.postRiskLevel,
            evidencePhotoData: a.evidencePhotoData,
            effectivenessResult: a.effectivenessResult, confirmedBy: a.confirmedBy,
            effectivenessConfirmedAt: a.effectivenessConfirmedAt)
    }

    static func restore(_ a: CorrectiveAction, _ s: FieldSnapshot) {
        a.measure = s.measure
        a.responsibleName = s.responsibleName
        a.dueDate = s.dueDate
        a.status = s.status
        a.implementedAt = s.implementedAt
        a.postRiskLevel = s.postRiskLevel
        a.evidencePhotoData = s.evidencePhotoData
        a.effectivenessResult = s.effectivenessResult
        a.confirmedBy = s.confirmedBy
        a.effectivenessConfirmedAt = s.effectivenessConfirmedAt
    }

    /// Applies edited fields under the STATUS-DRIVEN lifecycle:
    /// - 이행일·개선후위험도는 **.completed 전용** — 완료가 아니면 nil로 정규화(상태·이행일 모순 차단).
    /// - 효과확인은 **완료를 벗어나거나** 실질 필드(measure/status/이행일/개선후위험도)가 바뀌면 초기화된다.
    ///   초기화는 `effectivenessResult != nil` 여부에 **의존하지 않는다** — confirmedBy/confirmedAt 만 남은
    ///   손상 상태여도 세 필드를 항상 함께 nil로 만든다. responsibleName·dueDate·evidence는 비실질.
    /// `.completed` 인데 `implementedAt`이 없는 조합은 op(`CorrectiveActionEditing.update`)가 먼저 막는다.
    static func apply(
        to a: CorrectiveAction,
        measure: String?, responsibleName: String?, dueDate: Date?,
        status: CorrectiveActionStatus, implementedAt: Date?,
        postRiskLevel: RiskLevel?, evidencePhotoData: Data?
    ) {
        let normImplementedAt = (status == .completed) ? implementedAt : nil
        let normPostRiskLevel = (status == .completed) ? postRiskLevel : nil
        let substantiveChanged = a.measure != measure
            || a.status != status
            || a.implementedAt != normImplementedAt
            || a.postRiskLevel != normPostRiskLevel
        a.measure = measure
        a.responsibleName = responsibleName
        a.dueDate = dueDate
        a.status = status
        a.implementedAt = normImplementedAt
        a.postRiskLevel = normPostRiskLevel
        a.evidencePhotoData = evidencePhotoData
        if status != .completed || substantiveChanged {
            resetEffectiveness(a)
        }
    }

    /// 효과확인 불변조건 (SCHEMA_V3 §4.1): result·effectivenessConfirmedAt·confirmedBy 를 **하나의
    /// 도메인 동작으로 함께 갱신** — 부분 갱신 금지. 전제 검증·원자 저장은 `CorrectiveActionEditing.confirmEffectiveness`.
    static func applyEffectiveness(to a: CorrectiveAction, result: EffectivenessResult, by person: String, at date: Date) {
        a.effectivenessResult = result
        a.confirmedBy = person
        a.effectivenessConfirmedAt = date
    }

    /// Clears the 효과확인 triplet — back to 미확인. Always sets all three together.
    static func resetEffectiveness(_ a: CorrectiveAction) {
        a.effectivenessResult = nil
        a.confirmedBy = nil
        a.effectivenessConfirmedAt = nil
    }

    /// Restores the 효과확인 triplet verbatim — used to undo a failed commit in memory.
    static func restoreEffectiveness(_ a: CorrectiveAction, result: EffectivenessResult?, by person: String?, at date: Date?) {
        a.effectivenessResult = result
        a.confirmedBy = person
        a.effectivenessConfirmedAt = date
    }
}
