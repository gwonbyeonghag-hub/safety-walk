import Testing
import Foundation
import SafetyWalkCore

// WO LEGAL-2b §2 — a confirmation may ONLY record the suggestion computed from the item's
// current risk input under the locked criteria (no arbitrary decision). All three fields
// (criteriaDecision · decisionConfirmedAt · decisionConfirmedBy) are written together; a blank
// confirmer or 미입력 risk is refused. A confirmation is "current" only while the stored decision
// still equals the suggestion recomputed from the current input — a later risk change makes it
// STALE (not accepted as a current confirmation, not auto-cleared).

@Suite("RiskAssessmentItem — criteria decision confirmation (§2)")
struct CriteriaDecisionConfirmTests {

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private func scoreCriteria(_ threshold: Int) throws -> AcceptabilityCriteria {
        try AcceptabilityCriteria(matrix: .threeByThree, threshold: threshold, usesScore: true)
    }

    /// Computing a suggestion does NOT touch the item — it stays 미평가 until confirmed.
    @Test func suggestionAloneDoesNotPersist() throws {
        let c = try scoreCriteria(2)
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium) // score 4 → exceeds
        _ = c.suggestion(likelihood: item.likelihood, severity: item.severity, riskLevel: item.riskLevel)
        #expect(item.criteriaDecision == nil)
        #expect(item.decisionConfirmedAt == nil)
        #expect(item.decisionConfirmedBy == nil)
        #expect(item.hasCurrentCriteriaDecision(under: c) == false)
    }

    /// Confirmation records the COMPUTED suggestion (not an arbitrary value) — all three together.
    @Test func confirmRecordsComputedSuggestionAtomically() throws {
        let c = try scoreCriteria(2)
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium) // score 4 → exceeds
        try item.confirmCriteriaDecision(under: c, at: when, by: "홍길동")
        #expect(item.criteriaDecision == .exceedsThreshold)   // computed, not supplied
        #expect(item.decisionConfirmedAt == when)
        #expect(item.decisionConfirmedBy == "홍길동")
        #expect(item.hasCurrentCriteriaDecision(under: c) == true)
    }

    /// A blank confirmer is refused and writes nothing.
    @Test func confirmRejectsEmptyConfirmer() throws {
        let c = try scoreCriteria(2)
        let item = RiskAssessmentItem(likelihood: 1, severity: 1, riskLevel: .low)
        #expect(throws: CriteriaConfirmationError.emptyConfirmer) {
            try item.confirmCriteriaDecision(under: c, at: when, by: "   ")
        }
        #expect(item.criteriaDecision == nil)
        #expect(item.decisionConfirmedAt == nil)
        #expect(item.decisionConfirmedBy == nil)
    }

    /// Risk 미입력 → confirmation refused (no suggestion to record).
    @Test func confirmRejectsMissingRisk() throws {
        let c = try scoreCriteria(2)
        let item = RiskAssessmentItem()   // no likelihood/severity/riskLevel
        #expect(throws: CriteriaConfirmationError.riskNotEntered) {
            try item.confirmCriteriaDecision(under: c, at: when, by: "홍길동")
        }
        #expect(item.criteriaDecision == nil)
    }

    /// A risk change after confirmation makes the stored decision STALE — not current, not cleared.
    @Test func riskChangeMakesDecisionStale() throws {
        let c = try scoreCriteria(2)
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium) // 4 → exceeds
        try item.confirmCriteriaDecision(under: c, at: when, by: "홍길동")
        #expect(item.hasCurrentCriteriaDecision(under: c) == true)

        // Risk drops to 1×1 = 1 → within; the stored 'exceeds' no longer matches → stale.
        item.likelihood = 1; item.severity = 1; item.riskLevel = .low
        #expect(item.hasCurrentCriteriaDecision(under: c) == false)
        #expect(item.criteriaDecision == .exceedsThreshold)   // still stored (not auto-cleared)
    }

    /// A criteria change (different locked threshold) can also make a stored decision stale.
    @Test func criteriaChangeMakesDecisionStale() throws {
        let c2 = try scoreCriteria(2)
        let item = RiskAssessmentItem(likelihood: 1, severity: 3, riskLevel: .medium) // 3 → exceeds@2
        try item.confirmCriteriaDecision(under: c2, at: when, by: "홍길동")
        #expect(item.hasCurrentCriteriaDecision(under: c2) == true)
        // Under a 4-threshold criteria, score 3 is within → stored 'exceeds' is stale.
        let c4 = try scoreCriteria(4)
        #expect(item.hasCurrentCriteriaDecision(under: c4) == false)
    }

    /// Incomplete three-field records are never "current".
    @Test func incompleteThreeFieldsNotCurrent() throws {
        let c = try scoreCriteria(2)
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium)
        try item.confirmCriteriaDecision(under: c, at: when, by: "홍길동")
        item.decisionConfirmedBy = nil               // confirmer missing
        #expect(item.hasCurrentCriteriaDecision(under: c) == false)
    }
}
