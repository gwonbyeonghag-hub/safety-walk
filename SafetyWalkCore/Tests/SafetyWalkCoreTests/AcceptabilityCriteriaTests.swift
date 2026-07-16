import Testing
import Foundation
import SafetyWalkCore

// WO LEGAL-2b §3/§9 — the 기준 이내/초과 SUGGESTION is a pure function of the locked criteria.
// 빈도×강도·JSA: raw score ≤ acceptabilityThreshold(원점수). 3단계·체크리스트: risk-level
// rank (low=1, medium=2, high=3) ≤ acceptabilityThreshold(순위). Risk 미입력 → suggestion nil.
// A suggestion is NEVER a decision — the user must confirm it (tested separately).

@Suite("AcceptabilityCriteria — score threshold (빈도×강도/JSA)")
struct AcceptabilityScoreTests {

    /// Default threshold 2: scores 1–2 within, 3/4/6/9 exceed (WO §9).
    @Test func defaultThresholdTwo() throws {
        let c = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 2, usesScore: true)
        #expect(c.suggestion(likelihood: 1, severity: 1, riskLevel: nil) == .withinThreshold)  // 1
        #expect(c.suggestion(likelihood: 1, severity: 2, riskLevel: nil) == .withinThreshold)  // 2
        #expect(c.suggestion(likelihood: 1, severity: 3, riskLevel: nil) == .exceedsThreshold) // 3
        #expect(c.suggestion(likelihood: 2, severity: 2, riskLevel: nil) == .exceedsThreshold) // 4
        #expect(c.suggestion(likelihood: 2, severity: 3, riskLevel: nil) == .exceedsThreshold) // 6
        #expect(c.suggestion(likelihood: 3, severity: 3, riskLevel: nil) == .exceedsThreshold) // 9
    }

    /// Threshold 4: up to 4 within, 6/9 exceed (WO §9 "threshold 4이면 4까지 이내").
    @Test func thresholdFour() throws {
        let c = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 4, usesScore: true)
        #expect(c.suggestion(likelihood: 1, severity: 3, riskLevel: nil) == .withinThreshold)  // 3
        #expect(c.suggestion(likelihood: 2, severity: 2, riskLevel: nil) == .withinThreshold)  // 4
        #expect(c.suggestion(likelihood: 2, severity: 3, riskLevel: nil) == .exceedsThreshold) // 6
        #expect(c.suggestion(likelihood: 3, severity: 3, riskLevel: nil) == .exceedsThreshold) // 9
    }

    /// 위험도 미입력 → 제안 nil (both inputs required).
    @Test func missingScoreInputGivesNoSuggestion() throws {
        let c = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 2, usesScore: true)
        #expect(c.suggestion(likelihood: nil, severity: 3, riskLevel: nil) == nil)
        #expect(c.suggestion(likelihood: 2, severity: nil, riskLevel: nil) == nil)
        #expect(c.suggestion(likelihood: nil, severity: nil, riskLevel: .high) == nil)
    }

    /// WO §3 출시 정책: 빈도×강도/JSA 허용 임계값은 2·4 뿐. 그 외(1·3·5·0·9…)는 거부.
    @Test func onlyTwoAndFourAllowedForScore() {
        #expect(AcceptabilityCriteria.allowedThresholds(usesFrequencySeverity: true) == [2, 4])
        for bad in [0, 1, 3, 5, 9, 10] {
            #expect(throws: CriteriaError.invalidThreshold) {
                try AcceptabilityCriteria(matrix: .threeByThree, threshold: bad, usesScore: true)
            }
        }
        #expect(throws: Never.self) {
            _ = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 2, usesScore: true)
            _ = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 4, usesScore: true)
        }
    }
}

@Suite("AcceptabilityCriteria — rank threshold (3단계/체크리스트)")
struct AcceptabilityRankTests {

    /// Default threshold 1 (low only): low within, medium/high exceed (WO §9).
    @Test func defaultThresholdLow() throws {
        let c = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 1, usesScore: false)
        #expect(c.suggestion(likelihood: nil, severity: nil, riskLevel: .low) == .withinThreshold)
        #expect(c.suggestion(likelihood: nil, severity: nil, riskLevel: .medium) == .exceedsThreshold)
        #expect(c.suggestion(likelihood: nil, severity: nil, riskLevel: .high) == .exceedsThreshold)
    }

    /// Threshold 2 (low·medium): high exceeds only (WO §9 "direct threshold medium이면 medium까지 이내").
    @Test func thresholdMedium() throws {
        let c = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 2, usesScore: false)
        #expect(c.suggestion(likelihood: nil, severity: nil, riskLevel: .low) == .withinThreshold)
        #expect(c.suggestion(likelihood: nil, severity: nil, riskLevel: .medium) == .withinThreshold)
        #expect(c.suggestion(likelihood: nil, severity: nil, riskLevel: .high) == .exceedsThreshold)
    }

    @Test func missingLevelGivesNoSuggestion() throws {
        let c = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 1, usesScore: false)
        #expect(c.suggestion(likelihood: nil, severity: nil, riskLevel: nil) == nil)
    }

    /// WO §3: 3단계/체크리스트 허용 임계값은 1·2 뿐. 3(direct)·0·4 등은 거부.
    @Test func onlyLowAndMediumAllowedForRank() {
        #expect(AcceptabilityCriteria.allowedThresholds(usesFrequencySeverity: false) == [1, 2])
        for bad in [0, 3, 4] {
            #expect(throws: CriteriaError.invalidThreshold) {
                try AcceptabilityCriteria(matrix: .threeByThree, threshold: bad, usesScore: false)
            }
        }
        #expect(throws: Never.self) {
            _ = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 1, usesScore: false)
            _ = try AcceptabilityCriteria(matrix: .threeByThree, threshold: 2, usesScore: false)
        }
    }
}

@Suite("AcceptabilityCriteria — defaults + decode")
struct AcceptabilityDefaultsTests {

    @Test func defaultsMatchWO() {
        // 빈도×강도/JSA default = 2 (최고 기준 이내 원점수); 3단계/체크리스트 default = 1 (low만).
        #expect(AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true).threshold == 2)
        #expect(AcceptabilityCriteria.makeDefault(usesFrequencySeverity: false).threshold == 1)
    }

    /// Decode from the persisted columns round-trips the suggestion behaviour.
    @Test func decodeFromStoredColumns() throws {
        let data = try CriteriaMatrixSnapshot.threeByThree.encoded()
        let c = try AcceptabilityCriteria.decode(
            matrixData: data, matrixFormatVersion: 1, threshold: 2, usesFrequencySeverity: true)
        #expect(c.suggestion(likelihood: 2, severity: 2, riskLevel: nil) == .exceedsThreshold) // 4 > 2
    }

    /// A corrupt stored matrix is fail-closed at decode (no default substitution).
    @Test func decodeCorruptMatrixThrows() {
        #expect(throws: CriteriaError.emptyData) {
            try AcceptabilityCriteria.decode(
                matrixData: Data(), matrixFormatVersion: 1, threshold: 2, usesFrequencySeverity: true)
        }
    }
}
