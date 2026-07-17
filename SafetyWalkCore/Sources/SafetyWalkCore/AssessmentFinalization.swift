import Foundation

/// Finalize-READINESS check for a 위험성평가 (WO LEGAL-2b §4/§7). 2b ships ONLY this predicate —
/// the actual finalized button/state transition arrives with the 조치·공유 conditions in a later
/// WO (2c/2d). Keeping it here (Core, pure) lets both platforms gate a future "완료" the same way.
public enum AssessmentFinalization {

    /// True only when the assessment is ready to be finalized:
    /// - status is `.inProgress` (planned/finalized/cancelled are never ready),
    /// - a criteria exists, is locked (`lockedAt`), and FULLY decodes — matrix **and** threshold
    ///   (a corrupt snapshot or an out-of-policy threshold is fail-closed → not ready),
    /// - at least one item,
    /// - every item has its risk input AND a CURRENT confirmation: three decision fields present
    ///   and the stored decision still equals the suggestion recomputed from the current input
    ///   (a stale decision after a risk/criteria change makes it not ready),
    /// - every 기준 초과 item has a 개선조치 계획 (≥1 measure-bearing corrective action) — WO LEGAL-2c.
    public static func isReadyToFinalize(_ assessment: RiskAssessment) -> Bool {
        guard assessment.status == .inProgress else { return false }
        guard let stored = assessment.criteria, stored.lockedAt != nil else { return false }
        guard let criteria = try? AcceptabilityCriteria.decode(
            from: stored, usesFrequencySeverity: assessment.method.usesFrequencySeverity)
        else { return false }
        guard let items = assessment.items, !items.isEmpty else { return false }
        for item in items {
            guard item.riskLevel != nil,
                  item.hasCurrentCriteriaDecision(under: criteria),
                  CorrectiveActionPolicy.hasRequiredCorrectiveActionPlan(item)
            else { return false }
        }
        return true
    }
}
