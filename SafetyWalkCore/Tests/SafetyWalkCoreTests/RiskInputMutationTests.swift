import Testing
import Foundation
import SafetyWalkCore

// WO LEGAL-2b P1-2 — risk-input changes go through Core mutation ops that RESET the confirmation
// whenever any value actually changes, even if the resulting band is unchanged. Identical input is
// a no-op. (App code cannot assign the risk/confirmation fields directly — they are internal(set),
// so this compiles ONLY through the sanctioned ops, which is the "no direct assignment" guarantee.)

@Suite("RiskAssessmentItem — risk-input mutation resets confirmation (P1-2)")
struct RiskInputMutationTests {

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private func scoreCriteria(_ t: Int) throws -> AcceptabilityCriteria {
        try AcceptabilityCriteria(matrix: .threeByThree, threshold: t, usesScore: true)
    }

    private func confirmedFreqItem(_ l: Int, _ s: Int, _ level: RiskLevel, under c: AcceptabilityCriteria) throws -> RiskAssessmentItem {
        let item = RiskAssessmentItem(likelihood: l, severity: s, riskLevel: level)
        try item.confirmCriteriaDecision(under: c, at: when, by: "홍길동")
        return item
    }

    /// 2×2(초과) 확인 후 3×3(초과)로 변경 — 결과가 같은 초과여도 확인 3필드 전부 초기화.
    @Test func sameBandFreqChangeStillResets() throws {
        let c = try scoreCriteria(2)
        let item = try confirmedFreqItem(2, 2, .medium, under: c)   // score 4 → exceeds
        #expect(item.criteriaDecision == .exceedsThreshold)
        item.updateFrequencySeverityInput(likelihood: 3, severity: 3, using: .threeByThree) // 9 → high, still exceeds
        #expect(item.criteriaDecision == nil)
        #expect(item.decisionConfirmedAt == nil)
        #expect(item.decisionConfirmedBy == nil)
        #expect(item.riskLevel == .high)   // re-derived
    }

    /// 1×1(이내) 확인 후 1×2(이내)로 변경 — 결과가 같은 이내여도 초기화.
    @Test func sameWithinFreqChangeStillResets() throws {
        let c = try scoreCriteria(2)
        let item = try confirmedFreqItem(1, 1, .low, under: c)      // score 1 → within
        item.updateFrequencySeverityInput(likelihood: 1, severity: 2, using: .threeByThree) // 2 → still within
        #expect(item.criteriaDecision == nil)
        #expect(item.decisionConfirmedAt == nil)
        #expect(item.decisionConfirmedBy == nil)
    }

    /// 동일 입력 재설정 — 확인 유지(불필요한 초기화 없음).
    @Test func identicalFreqInputKeepsConfirmation() throws {
        let c = try scoreCriteria(2)
        let item = try confirmedFreqItem(2, 2, .medium, under: c)
        item.updateFrequencySeverityInput(likelihood: 2, severity: 2, using: .threeByThree)
        #expect(item.criteriaDecision == .exceedsThreshold)
        #expect(item.decisionConfirmedBy == "홍길동")
    }

    /// 범위 밖 위험 입력으로 변경 → riskLevel = nil (자동 위험도 금지, nil=미평가) + 확인 3필드 초기화.
    /// likelihood/severity 하한(1 미만)·상한(scale 초과) 모두 동일.
    @Test func outOfRangeFreqInputClearsRiskLevelAndConfirmation() throws {
        let c = try scoreCriteria(2)
        for (l, s) in [(0, 1), (4, 1), (1, 0), (1, 4)] {   // 3×3: scale 3
            let item = try confirmedFreqItem(2, 2, .medium, under: c)
            item.updateFrequencySeverityInput(likelihood: l, severity: s, using: .threeByThree)
            #expect(item.riskLevel == nil, "l\(l)×s\(s) must not auto-assign a risk level")
            #expect(item.likelihood == l)
            #expect(item.severity == s)
            #expect(item.criteriaDecision == nil)
            #expect(item.decisionConfirmedAt == nil)
            #expect(item.decisionConfirmedBy == nil)
        }
    }

    /// 곱셈 overflow → crash 없이 riskLevel = nil.
    @Test func overflowFreqInputClearsRiskLevel() throws {
        let c = try scoreCriteria(2)
        let item = try confirmedFreqItem(2, 2, .medium, under: c)
        item.updateFrequencySeverityInput(likelihood: Int.max, severity: 2, using: .threeByThree)
        #expect(item.riskLevel == nil)
        #expect(item.criteriaDecision == nil)
    }

    /// 정상 범위 입력은 matrix band 로 재도출.
    @Test func inRangeFreqInputDerivesBand() throws {
        let c = try scoreCriteria(2)
        let item = try confirmedFreqItem(1, 1, .low, under: c)
        item.updateFrequencySeverityInput(likelihood: 2, severity: 2, using: .threeByThree) // score 4 → medium
        #expect(item.riskLevel == .medium)
    }

    /// 직접 위험등급 Low 확인 후 Medium 으로 변경 — 초기화.
    @Test func directRiskLevelChangeResets() throws {
        let c = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 1, usesScore: false)
        let item = RiskAssessmentItem(riskLevel: .low)
        try item.confirmCriteriaDecision(under: c, at: when, by: "홍길동")   // low ≤ 1 → within
        #expect(item.criteriaDecision == .withinThreshold)
        item.updateDirectRiskLevel(.medium)
        #expect(item.criteriaDecision == nil)
        #expect(item.decisionConfirmedAt == nil)
        #expect(item.decisionConfirmedBy == nil)
        #expect(item.riskLevel == .medium)
    }

    /// 동일 등급 재설정 — 확인 유지.
    @Test func identicalDirectRiskLevelKeepsConfirmation() throws {
        let c = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 1, usesScore: false)
        let item = RiskAssessmentItem(riskLevel: .low)
        try item.confirmCriteriaDecision(under: c, at: when, by: "홍길동")
        item.updateDirectRiskLevel(.low)
        #expect(item.criteriaDecision == .withinThreshold)
    }
}
