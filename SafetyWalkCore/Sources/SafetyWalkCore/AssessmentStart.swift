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
        try start(assessment, criteria: criteria, now: now, in: context, commit: { try context.save() })
    }

    /// Testing seam for the commit step. Production always commits with `context.save()`; the
    /// mutations and `context.rollback()` are real SwiftData operations either way. This overload
    /// exists ONLY so a test can inject a throwing commit to exercise the rollback path — these
    /// CloudKit-ready models carry no `@Attribute(.unique)`, so a real `save()` cannot be made to
    /// throw catchably (disk failures abort rather than throw). Not part of the public API.
    @discardableResult
    static func start(
        _ assessment: RiskAssessment,
        criteria: AcceptabilityCriteria,
        now: Date,
        in context: ModelContext,
        commit: () throws -> Void
    ) throws -> AssessmentCriteria {
        guard assessment.status == .planned else { throw AssessmentStartError.notPlanned }
        guard assessment.criteria == nil else { throw AssessmentStartError.criteriaAlreadyLocked }

        // Value copy: encode the validated snapshot into the persisted blob (already validated on
        // the way into AcceptabilityCriteria, so encode is total here).
        let matrixData = try criteria.matrix.encoded()

        // Captured so the in-memory assessment can be restored on failure — `context.rollback()`
        // reverts the STORE but leaves the mutated instance dirty (a held reference would read a
        // phantom .inProgress otherwise).
        let priorAssessedAt = assessment.assessedAt
        let priorUpdatedAt = assessment.updatedAt

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
            try commit()
        } catch {
            context.rollback()
            // Restore the in-memory object to its pre-start state — atomic in memory as well as
            // in the store, so a retry sees .planned + no criteria (WO §5 부분 상태 없음).
            assessment.criteria = nil
            assessment.status = .planned
            assessment.assessedAt = priorAssessedAt
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
        return ac
    }
}
