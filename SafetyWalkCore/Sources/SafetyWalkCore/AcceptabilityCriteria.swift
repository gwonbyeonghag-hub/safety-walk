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

    /// The ONLY thresholds the launch policy permits (WO LEGAL-2b §3) — Core is the single
    /// source: 빈도×강도/JSA = [2, 4] (raw score); 3단계/체크리스트 = [1, 2] (level rank). The UI
    /// options and every decode/readiness path derive their allowed set from here.
    public static func allowedThresholds(usesFrequencySeverity: Bool) -> [Int] {
        usesFrequencySeverity ? [2, 4] : [1, 2]
    }

    private static func validateThreshold(_ threshold: Int, matrix: CriteriaMatrixSnapshot, usesScore: Bool) throws {
        guard allowedThresholds(usesFrequencySeverity: usesScore).contains(threshold) else {
            throw CriteriaError.invalidThreshold
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

    /// Decodes a locked `AssessmentCriteria` model for `method` (fail-closed). Single decode path
    /// shared by the detail view, the locked-criteria display, and the readiness predicate.
    public static func decode(from criteria: AssessmentCriteria, usesFrequencySeverity: Bool) throws -> AcceptabilityCriteria {
        try decode(matrixData: criteria.matrixData,
                   matrixFormatVersion: criteria.matrixFormatVersion,
                   threshold: criteria.acceptabilityThreshold,
                   usesFrequencySeverity: usesFrequencySeverity)
    }

    /// SafetyWalk default criteria for a method: the 3×3 matrix with the WO default threshold
    /// (빈도×강도/JSA = 2, 3단계/체크리스트 = 1). The inputs are compile-time valid, so this
    /// never throws — it is the *construction* of a default, not error recovery.
    public static func makeDefault(usesFrequencySeverity: Bool) -> AcceptabilityCriteria {
        let threshold = usesFrequencySeverity ? 2 : 1
        // swiftlint:disable:next force_try  — .threeByThree + {1,2} is always valid.
        return try! AcceptabilityCriteria(matrix: .threeByThree, threshold: threshold, usesScore: usesFrequencySeverity)
    }

    /// Convenience: the suggestion for a whole item's current risk input.
    public func suggestion(for item: RiskAssessmentItem) -> CriteriaDecision? {
        suggestion(likelihood: item.likelihood, severity: item.severity, riskLevel: item.riskLevel)
    }
}

/// Why a 기준 이내/초과 confirmation was refused (WO LEGAL-2b §2).
public enum CriteriaConfirmationError: Error, Equatable {
    case riskNotEntered   // 위험 입력 미기록 — 계산할 제안이 없음
    case emptyConfirmer   // 확인자 공백
}

public extension RiskAssessmentItem {

    /// Confirms the 기준 이내/초과 decision by RECORDING the suggestion computed from THIS item's
    /// current input under `criteria` — the only value that may be stored (WO §2, no arbitrary
    /// decision). Writes all three fields together; refuses a blank confirmer or 미입력 risk.
    func confirmCriteriaDecision(under criteria: AcceptabilityCriteria, at date: Date, by person: String) throws {
        guard !person.sw_isBlank else { throw CriteriaConfirmationError.emptyConfirmer }
        guard let decision = criteria.suggestion(for: self) else { throw CriteriaConfirmationError.riskNotEntered }
        criteriaDecision = decision
        decisionConfirmedAt = date
        decisionConfirmedBy = person
    }

    /// True only for a COMPLETE, CURRENT confirmation under `criteria`: all three fields present
    /// (non-blank confirmer) AND the stored decision still equals the suggestion recomputed from
    /// the current input. A later risk/criteria change makes a once-valid decision stale → false
    /// (WO §2). Incomplete or stale records are never treated as confirmed.
    func hasCurrentCriteriaDecision(under criteria: AcceptabilityCriteria) -> Bool {
        guard let stored = criteriaDecision,
              decisionConfirmedAt != nil,
              let by = decisionConfirmedBy, !by.sw_isBlank else { return false }
        return criteria.suggestion(for: self) == stored
    }
}
