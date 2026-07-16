import Foundation
import SwiftData

/// Why an assessment start was refused (validation-stage errors — persistence errors propagate
/// as the underlying thrown error so the caller can roll back and surface a localized message).
public enum AssessmentStartError: Error, Equatable {
    case notPlanned            // 재시작 금지 — only a `.planned` assessment may be started
    case criteriaAlreadyLocked // 잠긴 기준 재작성 금지 — the assessment already owns a criteria
}

/// The single 평가 시작 (planned → inProgress) rule, shared by both UI entry paths — the planned
/// detail's "평가 시작" and the immediate "assess now" create flow (WO LEGAL-2b §5). Starting is
/// ONE failable, atomic operation; on any failure the pending inserts roll back so no partial
/// state persists (SCHEMA_V3 §4.1).
public enum AssessmentStart {

    /// Starts `assessment`: creates & locks a value-copied `AssessmentCriteria`, links the
    /// inverse, stamps `assessedAt`/`updatedAt`, flips `status` to `.inProgress`, and saves.
    /// - The assessment (and any items for the immediate path) must already be inserted into
    ///   `context`; this performs the single `save()` that commits them together.
    /// - Throws `AssessmentStartError` if the assessment isn't `.planned` or already owns a
    ///   criteria, or the underlying persistence error (after rolling back) if `save()` fails.
    @discardableResult
    public static func start(
        _ assessment: RiskAssessment,
        criteria: AcceptabilityCriteria,
        now: Date,
        in context: ModelContext
    ) throws -> AssessmentCriteria {
        guard assessment.status == .planned else { throw AssessmentStartError.notPlanned }
        guard assessment.criteria == nil else { throw AssessmentStartError.criteriaAlreadyLocked }

        // Value copy: encode the validated snapshot into the persisted blob (already validated on
        // the way into AcceptabilityCriteria, so encode is total here).
        let matrixData = try criteria.matrix.encoded()

        let ac = AssessmentCriteria(
            matrixData: matrixData,
            matrixFormatVersion: 1,
            acceptabilityThreshold: criteria.threshold)
        ac.lockedAt = now
        context.insert(ac)
        ac.riskAssessment = assessment
        assessment.criteria = ac
        assessment.status = .inProgress
        assessment.assessedAt = now
        assessment.updatedAt = now

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return ac
    }
}
