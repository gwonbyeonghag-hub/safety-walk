import Foundation
import SwiftData

/// Why a 개선조치 편집 was refused (WO LEGAL-2c). Validation-stage errors; persistence errors
/// propagate as the underlying thrown error after `context.rollback()` + in-memory restore.
public enum CorrectiveActionError: Error, Equatable {
    case emptyMeasure                    // 감소대책(measure) 공백 — 빈 개선조치 저장 금지
    case assessmentNotEditable           // 평가가 inProgress/finalized 아님 (planned/cancelled=편집 불가)
    case itemNotInAssessment             // 항목이 해당 평가 소유 아님
    case actionNotInAssessment           // 조치가 해당 평가의 항목 소유 아님
    case completedRequiresImplementedAt  // .completed 저장에는 이행일 필수
    case effectivenessPreconditionUnmet  // 효과확인 전제(완료 상태·이행일·개선후위험도) 미충족
    case emptyConfirmer                  // 효과 확인자 공백
}

/// The atomic 개선조치(CorrectiveAction) 편집 ops — add / update / remove / confirmEffectiveness
/// (WO LEGAL-2c). Each guards fail-closed, mutates through the model's Core-only setters, and
/// persists with a store+memory restore on commit failure (the `AssessmentDecision` pattern):
/// `context.rollback()` reverts the store, and the catch block restores the in-memory instances,
/// so a failed save can never leave a phantom action or a phantom 효과확인 on screen.
///
/// Editable states = `.inProgress` (author the plan during assessment) and `.finalized`
/// (개선조치는 finalized 후에도 별도 수명주기로 수정 — LEGAL_2_ARCH §1). `.planned`/`.cancelled` refuse.
public enum CorrectiveActionEditing {

    // MARK: - add

    /// Adds a new corrective action to `item`. Requires a non-blank `measure` (빈 조치 차단). A new
    /// action is ALWAYS `.notStarted` with empty 이행일·개선후위험도·효과확인 — the completed lifecycle
    /// (이행일·개선후위험도·효과확인) is reached only later through `update`/`confirmEffectiveness`.
    @discardableResult
    public static func add(
        to item: RiskAssessmentItem,
        in assessment: RiskAssessment,
        measure: String,
        responsibleName: String? = nil,
        dueDate: Date? = nil,
        at date: Date,
        context: ModelContext
    ) throws -> CorrectiveAction {
        try add(to: item, in: assessment, measure: measure, responsibleName: responsibleName,
                dueDate: dueDate, at: date, context: context, commit: { try context.save() })
    }

    /// Testing seam for the commit step (see `AssessmentDecision` for the rationale — these
    /// unique-free CloudKit models can't be made to throw a catchable `save()`). Not public.
    @discardableResult
    static func add(
        to item: RiskAssessmentItem,
        in assessment: RiskAssessment,
        measure: String,
        responsibleName: String? = nil,
        dueDate: Date? = nil,
        at date: Date,
        context: ModelContext,
        commit: () throws -> Void
    ) throws -> CorrectiveAction {
        try requireEditable(assessment)
        guard (assessment.items ?? []).contains(where: { $0 === item }) else {
            throw CorrectiveActionError.itemNotInAssessment
        }

        // Sealed create contract: always .notStarted, non-blank measure enforced by the throwing init
        // (no separate requireMeasure here — the init is the single measure gate for creation).
        let action = try CorrectiveAction(item: item, measure: measure,
                                          responsibleName: responsibleName, dueDate: dueDate)

        let priorUpdatedAt = assessment.updatedAt
        context.insert(action)
        appendInPlace(action, to: item)            // in-place append (no array reassignment)
        assessment.updatedAt = date

        do {
            try commit()
        } catch {
            context.rollback()
            // `context.rollback()` reverts the STORE but leaves the in-memory relationship dirty,
            // and SwiftData re-syncs `item.correctiveActions` from the still-set `action.item` — so
            // detach the inverse first, then remove it in place (array replacement doesn't stick
            // while the inverse is still live).
            action.item = nil
            item.correctiveActions?.removeAll { $0 === action }
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
        return action
    }

    // MARK: - update

    /// Edits an existing corrective action. Requires a non-blank `measure`. A substantive change
    /// (measure/status/implementedAt/postRiskLevel) invalidates a prior 효과확인 (효과확인 무효화).
    public static func update(
        _ action: CorrectiveAction,
        in assessment: RiskAssessment,
        measure: String,
        responsibleName: String? = nil,
        dueDate: Date? = nil,
        status: CorrectiveActionStatus,
        implementedAt: Date? = nil,
        postRiskLevel: RiskLevel? = nil,
        evidencePhotoData: Data? = nil,
        at date: Date,
        context: ModelContext
    ) throws {
        try update(action, in: assessment, measure: measure, responsibleName: responsibleName,
                   dueDate: dueDate, status: status, implementedAt: implementedAt,
                   postRiskLevel: postRiskLevel, evidencePhotoData: evidencePhotoData,
                   at: date, context: context, commit: { try context.save() })
    }

    static func update(
        _ action: CorrectiveAction,
        in assessment: RiskAssessment,
        measure: String,
        responsibleName: String? = nil,
        dueDate: Date? = nil,
        status: CorrectiveActionStatus,
        implementedAt: Date? = nil,
        postRiskLevel: RiskLevel? = nil,
        evidencePhotoData: Data? = nil,
        at date: Date,
        context: ModelContext,
        commit: () throws -> Void
    ) throws {
        try requireEditable(assessment)
        try requireMeasure(measure)
        try requireActionInAssessment(action, assessment)
        // .completed 저장에는 이행일 필수 (상태·이행일 모순 차단). applyFields가 이후 완료-전용 필드를 정규화.
        if status == .completed, implementedAt == nil {
            throw CorrectiveActionError.completedRequiresImplementedAt
        }

        let prior = action.snapshotFields()
        let priorUpdatedAt = assessment.updatedAt
        action.applyFields(measure: measure, responsibleName: responsibleName, dueDate: dueDate,
                           status: status, implementedAt: implementedAt,
                           postRiskLevel: postRiskLevel, evidencePhotoData: evidencePhotoData)
        assessment.updatedAt = date

        do {
            try commit()
        } catch {
            context.rollback()
            action.restoreFields(prior)
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
    }

    // MARK: - remove

    /// Deletes a corrective action from its item (1:N — siblings are preserved).
    public static func remove(
        _ action: CorrectiveAction,
        in assessment: RiskAssessment,
        at date: Date,
        context: ModelContext
    ) throws {
        try remove(action, in: assessment, at: date, context: context, commit: { try context.save() })
    }

    static func remove(
        _ action: CorrectiveAction,
        in assessment: RiskAssessment,
        at date: Date,
        context: ModelContext,
        commit: () throws -> Void
    ) throws {
        try requireEditable(assessment)
        try requireActionInAssessment(action, assessment)
        guard let item = action.item else { throw CorrectiveActionError.actionNotInAssessment }

        let priorUpdatedAt = assessment.updatedAt
        item.correctiveActions?.removeAll { $0 === action }   // in-place remove (no array reassignment)
        context.delete(action)
        assessment.updatedAt = date

        do {
            try commit()
        } catch {
            context.rollback()
            // Re-attach the inverse and re-insert in place (rollback un-deletes the object but the
            // in-memory relationship stays dirty).
            action.item = item
            appendInPlace(action, to: item)
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
    }

    /// In-place append that tolerates SwiftData's inverse auto-sync (never duplicates the action).
    private static func appendInPlace(_ action: CorrectiveAction, to item: RiskAssessmentItem) {
        if item.correctiveActions == nil { item.correctiveActions = [] }
        if !(item.correctiveActions ?? []).contains(where: { $0 === action }) {
            item.correctiveActions?.append(action)
        }
    }

    // MARK: - confirmEffectiveness

    /// Records the 효과확인 result atomically. Precondition: 조치가 **완료(.completed)** 상태이고 이행일·
    /// 개선후위험도가 기록돼 있으며 확인자가 비어 있지 않아야 한다. Persists with a store+memory restore.
    public static func confirmEffectiveness(
        _ action: CorrectiveAction,
        in assessment: RiskAssessment,
        result: EffectivenessResult,
        by person: String,
        at date: Date,
        context: ModelContext
    ) throws {
        try confirmEffectiveness(action, in: assessment, result: result, by: person,
                                 at: date, context: context, commit: { try context.save() })
    }

    static func confirmEffectiveness(
        _ action: CorrectiveAction,
        in assessment: RiskAssessment,
        result: EffectivenessResult,
        by person: String,
        at date: Date,
        context: ModelContext,
        commit: () throws -> Void
    ) throws {
        try requireEditable(assessment)
        try requireActionInAssessment(action, assessment)
        guard action.isReadyForEffectivenessCheck else {
            throw CorrectiveActionError.effectivenessPreconditionUnmet
        }
        guard !person.sw_isBlank else { throw CorrectiveActionError.emptyConfirmer }

        let priorResult = action.effectivenessResult
        let priorBy = action.confirmedBy
        let priorAt = action.effectivenessConfirmedAt
        let priorUpdatedAt = assessment.updatedAt
        action.confirmEffectiveness(result: result, by: person, at: date)
        assessment.updatedAt = date

        do {
            try commit()
        } catch {
            context.rollback()
            action.restoreEffectiveness(result: priorResult, by: priorBy, at: priorAt)
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
    }

    // MARK: - Guards

    private static func requireEditable(_ assessment: RiskAssessment) throws {
        guard assessment.allowsCorrectiveActionEditing else {
            throw CorrectiveActionError.assessmentNotEditable
        }
    }

    private static func requireMeasure(_ measure: String) throws {
        guard !measure.sw_isBlank else { throw CorrectiveActionError.emptyMeasure }
    }

    private static func requireActionInAssessment(_ action: CorrectiveAction, _ assessment: RiskAssessment) throws {
        guard let item = action.item,
              (assessment.items ?? []).contains(where: { $0 === item }) else {
            throw CorrectiveActionError.actionNotInAssessment
        }
    }
}

public extension RiskAssessment {

    /// 개선조치 편집 가능 상태 — inProgress에서 계획하고 finalized 후에도 수정 가능(LEGAL_2_ARCH §1);
    /// planned/cancelled는 불가. Core op와 두 화면이 공유하는 단일 규칙(상태 3중 중복 제거).
    var allowsCorrectiveActionEditing: Bool {
        status == .inProgress || status == .finalized
    }
}

public extension RiskAssessmentItem {

    /// 기준 초과 항목인가 — 초과면 개선조치 계획이 필수(LEGAL_2_ARCH §1.1).
    var needsCorrectiveActionPlan: Bool {
        criteriaDecision == .exceedsThreshold
    }

    /// 초과 항목이면 ≥1 개선조치(감소대책 비어있지 않은)가 있어야 계획 충족. 초과가 아니면 항상 충족.
    var hasRequiredCorrectiveActionPlan: Bool {
        guard needsCorrectiveActionPlan else { return true }
        return (correctiveActions ?? []).contains { !($0.measure ?? "").sw_isBlank }
    }

    /// 기준 초과인데 아직 개선조치 계획이 없는 상태 — 상세·목록 화면의 "계획 필요" 안내 단일 소스.
    var isMissingRequiredCorrectiveActionPlan: Bool {
        needsCorrectiveActionPlan && !hasRequiredCorrectiveActionPlan
    }

    /// 1:N 개선조치를 결정적 순서로 반환 — CloudKit은 to-many 순서를 보장하지 않고 스키마에 sortOrder가
    /// 없으므로(동결) `id` 기준으로 안정 정렬한다. 화면·리포트가 같은 순서를 쓰도록 하는 단일 소스.
    var sortedCorrectiveActions: [CorrectiveAction] {
        (correctiveActions ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
