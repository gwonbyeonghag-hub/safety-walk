import Foundation

/// Decoded + validated acceptability criteria: the locked matrix snapshot plus its threshold.
/// This is the SINGLE place the 기준 이내/초과 suggestion is computed (WO LEGAL-2b §5 — no view
/// duplicates the formula). A suggestion is only ever a *proposal*; it becomes an item's
/// `criteriaDecision` only when the user confirms it.
///
/// `acceptabilityThreshold` semantics (WO §3):
/// - `usesScore == true`  (빈도×강도·JSA): 최고 "기준 이내" 원점수 (raw likelihood × severity).
/// - `usesScore == false` (3단계·체크리스트): 최고 "기준 이내" 순위 (low=1, medium=2, high=3).
public struct AcceptabilityCriteria: Equatable {

    public let matrix: CriteriaMatrixSnapshot
    public let threshold: Int
    public let usesScore: Bool

    /// Validates the threshold against the matrix/mode (fail-closed on an out-of-range value).
    public init(matrix: CriteriaMatrixSnapshot, threshold: Int, usesScore: Bool) throws {
        try matrix.validate()
        try Self.validateThreshold(threshold, matrix: matrix, usesScore: usesScore)
        self.matrix = matrix
        self.threshold = threshold
        self.usesScore = usesScore
    }

    private static func validateThreshold(_ threshold: Int, matrix: CriteriaMatrixSnapshot, usesScore: Bool) throws {
        if usesScore {
            guard threshold >= 1, threshold <= matrix.maxScore else { throw CriteriaError.invalidThreshold }
        } else {
            guard threshold >= 1, threshold <= 3 else { throw CriteriaError.invalidThreshold }
        }
    }

    /// Rank of a risk level for the 3단계/체크리스트 comparison (low=1, medium=2, high=3).
    static func rank(_ level: RiskLevel) -> Int {
        switch level {
        case .low:    return 1
        case .medium: return 2
        case .high:   return 3
        }
    }

    /// 기준 이내/초과 SUGGESTION for one item, or `nil` when the risk is 미입력 (제안 없음).
    /// 빈도×강도/JSA compares the raw score; 3단계/체크리스트 compares the level rank.
    public func suggestion(likelihood: Int?, severity: Int?, riskLevel: RiskLevel?) -> CriteriaDecision? {
        if usesScore {
            guard let l = likelihood, let s = severity else { return nil }
            return (l * s) <= threshold ? .withinThreshold : .exceedsThreshold
        } else {
            guard let level = riskLevel else { return nil }
            return Self.rank(level) <= threshold ? .withinThreshold : .exceedsThreshold
        }
    }

    /// Returns a copy with a different threshold (re-validated) — used by the criteria UI when
    /// the user changes the default before starting.
    public func withThreshold(_ newThreshold: Int) throws -> AcceptabilityCriteria {
        try AcceptabilityCriteria(matrix: matrix, threshold: newThreshold, usesScore: usesScore)
    }

    // MARK: - Persistence bridge

    /// Decodes from the stored `AssessmentCriteria` columns (fail-closed).
    public static func decode(
        matrixData: Data,
        matrixFormatVersion: Int,
        threshold: Int,
        usesFrequencySeverity: Bool
    ) throws -> AcceptabilityCriteria {
        let matrix = try CriteriaMatrixSnapshot.decode(matrixData, formatVersion: matrixFormatVersion)
        return try AcceptabilityCriteria(matrix: matrix, threshold: threshold, usesScore: usesFrequencySeverity)
    }

    /// SafetyWalk default criteria for a method: the 3×3 matrix with the WO default threshold
    /// (빈도×강도/JSA = 2, 3단계/체크리스트 = 1). The inputs are compile-time valid, so this
    /// never throws — it is the *construction* of a default, not error recovery.
    public static func makeDefault(usesFrequencySeverity: Bool) -> AcceptabilityCriteria {
        let threshold = usesFrequencySeverity ? 2 : 1
        // swiftlint:disable:next force_try  — .threeByThree + {1,2} is always valid.
        return try! AcceptabilityCriteria(matrix: .threeByThree, threshold: threshold, usesScore: usesFrequencySeverity)
    }
}
