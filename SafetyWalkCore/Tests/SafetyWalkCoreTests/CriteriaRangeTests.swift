import Testing
import Foundation
@testable import SafetyWalkCore

// WO LEGAL-2b P1-3 — 위험 입력 범위와 계산 등급 일치 검증. Out-of-range likelihood/severity, score
// overflow, and a stored riskLevel that disagrees with the matrix band are all fail-closed: the
// numeric suggestion returns nil, the item-based suggestion returns nil, confirmation is refused,
// and readiness is false. Scale multiplication overflow throws instead of crashing.

@Suite("AcceptabilityCriteria — range / overflow / consistency (P1-3)")
struct CriteriaRangeTests {

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private func score(_ t: Int) throws -> AcceptabilityCriteria {
        try AcceptabilityCriteria(matrix: .threeByThree, threshold: t, usesScore: true)
    }

    /// 순수 수치 제안 API: 범위 밖 likelihood/severity → nil.
    @Test func numericSuggestionNilOutOfRange() throws {
        let c = try score(2)
        #expect(c.suggestion(likelihood: 0, severity: 1, riskLevel: nil) == nil)  // l < 1
        #expect(c.suggestion(likelihood: 4, severity: 1, riskLevel: nil) == nil)  // l > scale 3
        #expect(c.suggestion(likelihood: 1, severity: 0, riskLevel: nil) == nil)  // s < 1
        #expect(c.suggestion(likelihood: 1, severity: 4, riskLevel: nil) == nil)  // s > scale 3
        #expect(c.suggestion(likelihood: 2, severity: 2, riskLevel: nil) == .exceedsThreshold) // in-range 4
    }

    /// 항목 기반 제안: 범위 밖(0×1 + Low, 4×1) → nil, 계산 등급과 저장 riskLevel 불일치(1×1 + High) → nil,
    /// 유효 조합(2×2 + Medium) → 정상.
    @Test func itemSuggestionRangeAndConsistency() throws {
        let c = try score(2)
        #expect(c.suggestion(for: RiskAssessmentItem(likelihood: 0, severity: 1, riskLevel: .low)) == nil)
        #expect(c.suggestion(for: RiskAssessmentItem(likelihood: 4, severity: 1, riskLevel: .low)) == nil)
        #expect(c.suggestion(for: RiskAssessmentItem(likelihood: 1, severity: 1, riskLevel: .high)) == nil) // band(1)=low≠high
        #expect(c.suggestion(for: RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium)) == .exceedsThreshold)
    }

    /// 범위 밖 / 불일치 항목은 확정도 거부된다.
    @Test func confirmRefusedForInvalidItem() throws {
        let c = try score(2)
        #expect(throws: CriteriaConfirmationError.riskNotEntered) {
            try RiskAssessmentItem(likelihood: 1, severity: 1, riskLevel: .high)   // mismatch
                .confirmCriteriaDecision(under: c, at: when, by: "홍길동")
        }
        #expect(throws: CriteriaConfirmationError.riskNotEntered) {
            try RiskAssessmentItem(likelihood: 0, severity: 1, riskLevel: .low)    // out of range
                .confirmCriteriaDecision(under: c, at: when, by: "홍길동")
        }
    }

    /// 불일치 항목은 완전 확인이 될 수 없다(hasCurrentCriteriaDecision false).
    @Test func mismatchIsNeverCurrent() throws {
        let c = try score(2)
        // A (persisted-style) item whose stored decision doesn't match the (mismatched) recompute.
        let item = RiskAssessmentItem(likelihood: 1, severity: 1, riskLevel: .high)
        item.criteriaDecision = .withinThreshold
        item.decisionConfirmedAt = when
        item.decisionConfirmedBy = "홍길동"
        #expect(item.hasCurrentCriteriaDecision(under: c) == false)  // suggestion(for:) is nil → not current
    }

    /// scale 곱셈 overflow 는 crash 하지 않고 CriteriaError.scaleOverflow 로 실패.
    @Test func scaleOverflowThrows() {
        let bad = CriteriaMatrixSnapshot(likelihoodScale: Int.max, severityScale: 2,
                                         bands: [.init(maxScore: Int.max, level: .high)])
        #expect(throws: CriteriaError.scaleOverflow) { try bad.validate() }
    }

    /// score 임계값은 {2,4} 인 동시에 해당 matrix에서 도달 가능해야 한다: maxScore=2 matrix에서 4는 거부.
    @Test func scoreThresholdMustBeReachable() throws {
        let small = CriteriaMatrixSnapshot(likelihoodScale: 2, severityScale: 1,
                                           bands: [.init(maxScore: 1, level: .low), .init(maxScore: 2, level: .high)])
        #expect(throws: CriteriaError.invalidThreshold) {
            try AcceptabilityCriteria(matrix: small, threshold: 4, usesScore: true)   // 4 > maxScore 2
        }
        #expect(throws: Never.self) {
            _ = try AcceptabilityCriteria(matrix: small, threshold: 2, usesScore: true) // 2 ≤ maxScore 2
        }
    }
}
