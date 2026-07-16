import Foundation
import SwiftData

/// Why a 기준 이내/초과 confirmation was refused at the assessment level (WO LEGAL-2b P1-1).
/// (Field-level refusals — 미입력 risk / blank confirmer — surface as `CriteriaConfirmationError`;
/// a fail-closed criteria decode surfaces as `CriteriaError`.)
public enum AssessmentDecisionError: Error, Equatable {
    case notInProgress        // 평가가 .inProgress 가 아님
    case itemNotInAssessment  // 항목이 해당 평가 소유가 아님
    case criteriaMissing      // 잠긴 기준이 없음
}

/// The single atomic 기준 결정 확인 operation, shared by the UI (WO LEGAL-2b P1-1). It decodes the
/// assessment's locked criteria itself, records the computed decision + `assessment.updatedAt` in
/// one step, and — crucially — on a commit failure both `rollback()`s the store AND restores the
/// in-memory instances, so a failed save can never leave the screen showing a phantom confirmation.
public enum AssessmentDecision {

    /// Confirms `item`'s decision within `assessment` and persists it. Throws (rethrowing the
    /// underlying error after rollback) on any validation/persistence failure.
    public static func confirm(
        item: RiskAssessmentItem,
        in assessment: RiskAssessment,
        by person: String,
        at date: Date,
        context: ModelContext
    ) throws {
        try confirm(item: item, in: assessment, by: person, at: date, context: context,
                    commit: { try context.save() })
    }

    /// Testing seam for the commit step (see `AssessmentStart` for the same rationale — these
    /// unique-free CloudKit models can't be made to throw a catchable `save()`). Not public.
    static func confirm(
        item: RiskAssessmentItem,
        in assessment: RiskAssessment,
        by person: String,
        at date: Date,
        context: ModelContext,
        commit: () throws -> Void
    ) throws {
        guard assessment.status == .inProgress else { throw AssessmentDecisionError.notInProgress }
        guard (assessment.items ?? []).contains(where: { $0 === item }) else {
            throw AssessmentDecisionError.itemNotInAssessment
        }
        guard let stored = assessment.criteria, stored.lockedAt != nil else {
            throw AssessmentDecisionError.criteriaMissing
        }
        // Decode the LOCKED criteria in full (fail-closed) — the View never passes a decision.
        let criteria = try AcceptabilityCriteria.decode(
            from: stored, usesFrequencySeverity: assessment.method.usesFrequencySeverity)

        // Capture prior state so a failed commit can be undone in memory too.
        let priorDecision = item.criteriaDecision
        let priorAt = item.decisionConfirmedAt
        let priorBy = item.decisionConfirmedBy
        let priorUpdatedAt = assessment.updatedAt

        // Records ONLY the computed suggestion; throws on 미입력 risk / blank confirmer.
        try item.confirmCriteriaDecision(under: criteria, at: date, by: person)
        assessment.updatedAt = date

        do {
            try commit()
        } catch {
            context.rollback()
            item.criteriaDecision = priorDecision
            item.decisionConfirmedAt = priorAt
            item.decisionConfirmedBy = priorBy
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
    }
}
