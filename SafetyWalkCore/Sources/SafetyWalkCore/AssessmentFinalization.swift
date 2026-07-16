import Foundation

/// Finalize-READINESS check for a 위험성평가 (WO LEGAL-2b §7). 2b ships ONLY this predicate — the
/// actual finalized button/state transition arrives with the 조치·공유 conditions in a later WO
/// (2c/2d). Keeping it here (Core, pure) lets both platforms gate a future "완료" the same way.
public enum AssessmentFinalization {

    /// True when the assessment is ready to be finalized:
    /// - at least one item,
    /// - every item has a `riskLevel` AND a fully-confirmed decision
    ///   (`criteriaDecision` · `decisionConfirmedAt` · non-blank `decisionConfirmedBy`),
    /// - a criteria exists, is locked (`lockedAt`), and its matrix snapshot still decodes
    ///   (fail-closed: a corrupt snapshot is NOT ready).
    public static func isReadyToFinalize(_ assessment: RiskAssessment) -> Bool {
        guard let items = assessment.items, !items.isEmpty else { return false }
        for item in items {
            guard item.riskLevel != nil,
                  item.criteriaDecision != nil,
                  item.decisionConfirmedAt != nil,
                  let by = item.decisionConfirmedBy, !by.sw_isBlank
            else { return false }
        }
        guard let criteria = assessment.criteria, criteria.lockedAt != nil else { return false }
        guard (try? CriteriaMatrixSnapshot.decode(criteria.matrixData,
                                                  formatVersion: criteria.matrixFormatVersion)) != nil
        else { return false }
        return true
    }
}
