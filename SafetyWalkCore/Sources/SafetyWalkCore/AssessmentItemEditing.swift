import Foundation
import SwiftData

/// 항목 편집이 거부된 이유 (WO LEGAL-2d-PATH §4). 영속 오류는 store·메모리 원복 후 재전파된다.
public enum AssessmentItemError: Error, Equatable {
    case assessmentNotEditable      // finalized/cancelled 는 항목이 잠긴다
    case itemNotInAssessment        // 다른 평가의 항목
    case emptyTaskDescription
    case emptyHazardDescription
    case unassessedItem             // 위험성 수준을 해결할 수 없음 (미평가 저장 금지)
    case criteriaUnreadable         // 잠긴 기준 decode 실패 — 손상된 기준으로 평가하지 않는다(fail-closed)
}

/// 평가 항목의 원자 편집 — add / update / remove (WO LEGAL-2d-PATH §4).
///
/// **잠금 시점**(LEGAL_2_ARCH §1 · SCHEMA_V3 §7): 항목은 `finalized` 에 잠긴다. 따라서 `planned`
/// (계획 작성 중)과 `inProgress`(평가 진행 중) 두 상태에서만 편집할 수 있고, `finalized`·`cancelled`
/// 에서는 세 연산 모두 거부한다.
///
/// 위험 입력이 바뀌면 **기존 모델 API**(`updateFrequencySeverityInput` / `updateDirectRiskLevel`)를
/// 그대로 거친다 — 그 API 가 기준확인 3필드를 무효화하므로, 위험도만 바뀌고 낡은 "확인 완료"가 남는
/// 상태를 만들 수 없다. 이 타입은 그 규칙을 재구현하지 않는다.
public enum AssessmentItemEditing {

    /// 항목 편집 가능 상태 — 화면의 버튼 활성화와 Core 전제가 공유하는 단일 규칙.
    public static func allowsItemEditing(_ assessment: RiskAssessment) -> Bool {
        assessment.status == .planned || assessment.status == .inProgress
    }

    // MARK: - add

    @discardableResult
    public static func add(
        to assessment: RiskAssessment,
        task: String,
        hazard: String,
        currentControls: String? = nil,
        likelihood: Int? = nil,
        severity: Int? = nil,
        riskLevel: RiskLevel? = nil,
        linkedHazardId: UUID? = nil,
        at date: Date,
        context: ModelContext
    ) throws -> RiskAssessmentItem {
        try add(to: assessment, task: task, hazard: hazard, currentControls: currentControls,
                likelihood: likelihood, severity: severity, riskLevel: riskLevel,
                linkedHazardId: linkedHazardId, at: date, context: context,
                commit: { try context.save() })
    }

    /// Testing seam for the commit step. Not public.
    @discardableResult
    static func add(
        to assessment: RiskAssessment,
        task: String,
        hazard: String,
        currentControls: String? = nil,
        likelihood: Int? = nil,
        severity: Int? = nil,
        riskLevel: RiskLevel? = nil,
        linkedHazardId: UUID? = nil,
        at date: Date,
        context: ModelContext,
        commit: () throws -> Void
    ) throws -> RiskAssessmentItem {
        try requireEditable(assessment)
        try requireText(task: task, hazard: hazard)
        let isFreq = assessment.method.usesFrequencySeverity
        let level = try resolvedLevel(for: assessment, likelihood: likelihood,
                                      severity: severity, direct: riskLevel)

        let priorUpdatedAt = assessment.updatedAt
        let nextOrder = ((assessment.items ?? []).map(\.sortOrder).max() ?? -1) + 1
        let item = RiskAssessmentItem(
            taskDescription: task.trimmed,
            hazardDescription: hazard.trimmed,
            currentControls: currentControls?.trimmedOrNil,
            likelihood: isFreq ? likelihood : nil,
            severity: isFreq ? severity : nil,
            riskLevel: level,
            linkedHazardId: linkedHazardId,
            sortOrder: nextOrder)
        context.insert(item)
        item.riskAssessment = assessment
        appendInPlace(item, to: assessment)
        assessment.updatedAt = date

        do {
            try commit()
        } catch {
            // inverse 를 먼저 끊고 in-place 로 제거한 뒤 rollback 한다 — 관계가 살아 있으면 SwiftData 가
            // `assessment.items` 를 다시 동기화해 메모리에 유령 항목이 남는다(`create` 와 같은 순서).
            item.riskAssessment = nil
            assessment.items?.removeAll { $0 === item }
            context.delete(item)
            context.rollback()
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
        return item
    }

    // MARK: - update

    public static func update(
        _ item: RiskAssessmentItem,
        in assessment: RiskAssessment,
        task: String,
        hazard: String,
        currentControls: String? = nil,
        likelihood: Int? = nil,
        severity: Int? = nil,
        riskLevel: RiskLevel? = nil,
        linkedHazardId: UUID? = nil,
        at date: Date,
        context: ModelContext
    ) throws {
        try update(item, in: assessment, task: task, hazard: hazard, currentControls: currentControls,
                   likelihood: likelihood, severity: severity, riskLevel: riskLevel,
                   linkedHazardId: linkedHazardId, at: date, context: context,
                   commit: { try context.save() })
    }

    static func update(
        _ item: RiskAssessmentItem,
        in assessment: RiskAssessment,
        task: String,
        hazard: String,
        currentControls: String? = nil,
        likelihood: Int? = nil,
        severity: Int? = nil,
        riskLevel: RiskLevel? = nil,
        linkedHazardId: UUID? = nil,
        at date: Date,
        context: ModelContext,
        commit: () throws -> Void
    ) throws {
        try requireEditable(assessment)
        try requireItemInAssessment(item, assessment)
        try requireText(task: task, hazard: hazard)
        _ = try resolvedLevel(for: assessment, likelihood: likelihood,
                              severity: severity, direct: riskLevel)

        let prior = FieldSnapshot(item)
        let priorUpdatedAt = assessment.updatedAt
        item.taskDescription = task.trimmed
        item.hazardDescription = hazard.trimmed
        item.currentControls = currentControls?.trimmedOrNil
        item.linkedHazardId = linkedHazardId
        // 위험 입력은 기존 모델 API 로만 — 값이 실제로 바뀌면 그 안에서 기준확인이 무효화된다.
        if assessment.method.usesFrequencySeverity {
            item.updateFrequencySeverityInput(likelihood: likelihood, severity: severity,
                                              using: try matrix(for: assessment))
        } else {
            item.updateDirectRiskLevel(riskLevel)
        }
        assessment.updatedAt = date

        do {
            try commit()
        } catch {
            context.rollback()
            prior.restore(to: item)
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
    }

    // MARK: - remove

    public static func remove(
        _ item: RiskAssessmentItem,
        in assessment: RiskAssessment,
        at date: Date,
        context: ModelContext
    ) throws {
        try remove(item, in: assessment, at: date, context: context, commit: { try context.save() })
    }

    static func remove(
        _ item: RiskAssessmentItem,
        in assessment: RiskAssessment,
        at date: Date,
        context: ModelContext,
        commit: () throws -> Void
    ) throws {
        try requireEditable(assessment)
        try requireItemInAssessment(item, assessment)

        let priorUpdatedAt = assessment.updatedAt
        assessment.items?.removeAll { $0 === item }     // in-place remove
        context.delete(item)                            // cascade 가 이 항목의 개선조치를 함께 지운다
        assessment.updatedAt = date

        do {
            try commit()
        } catch {
            context.rollback()
            item.riskAssessment = assessment
            appendInPlace(item, to: assessment)
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
    }

    // MARK: - Guards / helpers

    private static func requireEditable(_ assessment: RiskAssessment) throws {
        guard allowsItemEditing(assessment) else { throw AssessmentItemError.assessmentNotEditable }
    }

    private static func requireItemInAssessment(_ item: RiskAssessmentItem,
                                                _ assessment: RiskAssessment) throws {
        guard (assessment.items ?? []).contains(where: { $0 === item }) else {
            throw AssessmentItemError.itemNotInAssessment
        }
    }

    private static func requireText(task: String, hazard: String) throws {
        guard !task.sw_isBlank else { throw AssessmentItemError.emptyTaskDescription }
        guard !hazard.sw_isBlank else { throw AssessmentItemError.emptyHazardDescription }
    }

    /// 위험도 파생에 쓸 매트릭스 — 화면과 Core 가 같은 값을 쓰도록 하는 단일 소스.
    ///
    /// 잠긴 기준이 있으면 **반드시 그것을** 쓴다. decode 에 실패하면 기본 매트릭스로 조용히 대체하지
    /// 않고 던진다 — 손상된 기준으로 항목을 "평가됨"으로 저장하면 fail-open 이 되기 때문이다
    /// (SCHEMA_V3 §7 · LEGAL_2_ARCH §2.1 fail-closed). 기준이 아직 없는 `planned` 단계에서만
    /// 기법 기본값을 쓴다.
    static func matrix(for assessment: RiskAssessment) throws -> CriteriaMatrixSnapshot {
        let isFreq = assessment.method.usesFrequencySeverity
        guard let stored = assessment.criteria else {
            return AcceptabilityCriteria.makeDefault(usesFrequencySeverity: isFreq).matrix
        }
        guard let decoded = try? AcceptabilityCriteria.decode(from: stored, usesFrequencySeverity: isFreq)
        else { throw AssessmentItemError.criteriaUnreadable }
        return decoded.matrix
    }

    /// 저장될 위험성 수준을 미리 확정한다 — nil 이면 미평가이므로 **context 를 건드리기 전에** 거부한다.
    private static func resolvedLevel(for assessment: RiskAssessment,
                                      likelihood: Int?, severity: Int?,
                                      direct: RiskLevel?) throws -> RiskLevel {
        let level = assessment.method.usesFrequencySeverity
            ? try matrix(for: assessment).inRangeBand(likelihood: likelihood, severity: severity)
            : direct
        guard let level else { throw AssessmentItemError.unassessedItem }
        return level
    }

    /// In-place append that tolerates SwiftData's inverse auto-sync (never duplicates the item).
    private static func appendInPlace(_ item: RiskAssessmentItem, to assessment: RiskAssessment) {
        if assessment.items == nil { assessment.items = [] }
        if !(assessment.items ?? []).contains(where: { $0 === item }) {
            assessment.items?.append(item)
        }
    }

    /// 편집 전 필드 사본 — 실패한 commit 을 메모리에서 되돌린다(`rollback()` 은 store 만 되돌린다).
    private struct FieldSnapshot {
        let task: String, hazard: String, controls: String?, linkedHazardId: UUID?
        let likelihood: Int?, severity: Int?, riskLevel: RiskLevel?
        let decision: CriteriaDecision?, confirmedAt: Date?, confirmedBy: String?

        init(_ i: RiskAssessmentItem) {
            task = i.taskDescription; hazard = i.hazardDescription; controls = i.currentControls
            linkedHazardId = i.linkedHazardId
            likelihood = i.likelihood; severity = i.severity; riskLevel = i.riskLevel
            decision = i.criteriaDecision
            confirmedAt = i.decisionConfirmedAt; confirmedBy = i.decisionConfirmedBy
        }

        func restore(to i: RiskAssessmentItem) {
            i.taskDescription = task; i.hazardDescription = hazard; i.currentControls = controls
            i.linkedHazardId = linkedHazardId
            i.likelihood = likelihood; i.severity = severity; i.riskLevel = riskLevel
            i.criteriaDecision = decision
            i.decisionConfirmedAt = confirmedAt; i.decisionConfirmedBy = confirmedBy
        }
    }
}
