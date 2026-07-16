import Testing
import Foundation
import SafetyWalkCore

// WO LEGAL-2b §5 — the suggestion never persists on its own; only an explicit user confirmation
// writes criteriaDecision + decisionConfirmedAt + decisionConfirmedBy, and it writes all three
// together (atomic, 교정 #3). If the risk input (or locked criteria) changes, all three clear.

@Suite("RiskAssessmentItem — criteria decision confirmation")
struct CriteriaDecisionConfirmTests {

    private let when = Date(timeIntervalSince1970: 1_700_000_000)

    /// Computing a suggestion does NOT touch the item — it stays 미평가 until confirmed.
    @Test func suggestionAloneDoesNotPersist() throws {
        let c = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 2, usesScore: true)
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium) // score 4 → exceeds
        _ = c.suggestion(likelihood: item.likelihood, severity: item.severity, riskLevel: item.riskLevel)
        #expect(item.criteriaDecision == nil)
        #expect(item.decisionConfirmedAt == nil)
        #expect(item.decisionConfirmedBy == nil)
    }

    /// Confirmation writes all three fields together.
    @Test func confirmWritesAllThreeAtomically() {
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium)
        item.confirmCriteriaDecision(.exceedsThreshold, at: when, by: "홍길동")
        #expect(item.criteriaDecision == .exceedsThreshold)
        #expect(item.decisionConfirmedAt == when)
        #expect(item.decisionConfirmedBy == "홍길동")
    }

    /// Clearing removes all three (nothing stale lingers).
    @Test func clearRemovesAllThree() {
        let item = RiskAssessmentItem(riskLevel: .low)
        item.confirmCriteriaDecision(.withinThreshold, at: when, by: "홍길동")
        item.clearCriteriaDecision()
        #expect(item.criteriaDecision == nil)
        #expect(item.decisionConfirmedAt == nil)
        #expect(item.decisionConfirmedBy == nil)
        #expect(item.isAssessed == false)   // riskLevel set but decision cleared → still 미평가 for finalize
    }
}
