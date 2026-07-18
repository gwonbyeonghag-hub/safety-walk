import Foundation

/// Fail-closed errors raised while decoding/validating a locked criteria snapshot or its
/// threshold (SCHEMA_V3 §7 · WO LEGAL-2b §5). A malformed blob must THROW — it is never
/// silently replaced with a default (교정 #6: matrixData 디코딩 실패 = fail-closed).
public enum CriteriaError: Error, Equatable {
    case emptyData                       // 빈 Data
    case unsupportedFormatVersion(Int)   // 미지원 format version
    case corruptedData                   // 손상된 JSON
    case nonPositiveScale                // 0 이하 scale
    case scaleOverflow                   // likelihoodScale × severityScale 곱셈 overflow
    case emptyBands                      // 밴드 없음
    case bandsNotAscending               // 중복·역순 band
    case maxScoreNotCovered              // 최대 점수 미포함
    case invalidThreshold                // 유효하지 않은 threshold
}

/// Value-copied acceptability matrix stored in `AssessmentCriteria.matrixData` (format v1).
/// A raw score (likelihood × severity) resolves to a `RiskLevel` band via ascending boundaries;
/// the bands must cover the full range up to the maximum possible score. This is the persisted
/// snapshot form — `RiskMatrixConfig` remains the live editor helper (WO LEGAL-2b §5).
public struct CriteriaMatrixSnapshot: Equatable {

    /// One band boundary: every score ≤ `maxScore` (and above the previous band) resolves to
    /// `level`. Bands are strictly ascending by `maxScore`; the last covers the maximum score.
    public struct Band: Equatable, Codable {
        public var maxScore: Int
        public var level: RiskLevel
        public init(maxScore: Int, level: RiskLevel) {
            self.maxScore = maxScore
            self.level = level
        }
    }

    public var likelihoodScale: Int
    public var severityScale: Int
    public var bands: [Band]

    public init(likelihoodScale: Int, severityScale: Int, bands: [Band]) {
        self.likelihoodScale = likelihoodScale
        self.severityScale = severityScale
        self.bands = bands
    }

    /// Value-copies a persisted snapshot from the live `RiskMatrixConfig` (WO §6 single source):
    /// same scales + bands, with the config's open-ended `.max` top boundary NORMALIZED down to
    /// the real maximum score so the snapshot has a concrete, complete range (no new abstraction).
    public init(from config: RiskMatrixConfig) {
        let maxScore = config.likelihoodScale * config.severityScale
        self.likelihoodScale = config.likelihoodScale
        self.severityScale = config.severityScale
        self.bands = config.bands.map { Band(maxScore: min($0.maxScore, maxScore), level: $0.level) }
    }

    /// Maximum possible raw score for this matrix (likelihood × severity at full scale).
    public var maxScore: Int { likelihoodScale * severityScale }

    /// The same matrix as a live `RiskMatrixConfig`, so a screen that draws a live band preview can
    /// use **the assessment's locked matrix** instead of re-hardcoding 3×3 (WO LEGAL-2d-PATH). The
    /// round-trip is lossless for the fields both types carry — `init(from:)` only normalizes the
    /// open-ended top boundary down to `maxScore`, which is already this snapshot's real range.
    public var asRiskMatrixConfig: RiskMatrixConfig {
        RiskMatrixConfig(likelihoodScale: likelihoodScale,
                         severityScale: severityScale,
                         bands: bands.map { .init(maxScore: $0.maxScore, level: $0.level) })
    }

    /// Default 3×3 (WO LEGAL-2b §5/§6): value-copied from `RiskMatrixConfig.threeByThree`
    /// (1~2 low, 3~4 medium, 5~9 high) — never re-hardcoded here.
    public static let threeByThree = CriteriaMatrixSnapshot(from: .threeByThree)

    /// Band for a raw score (first band whose `maxScore` the score does not exceed).
    public func band(forScore score: Int) -> RiskLevel {
        for band in bands where score <= band.maxScore { return band.level }
        return bands.last?.level ?? .high
    }

    /// The in-range raw score for likelihood × severity, or nil if either input is missing, outside
    /// `1...scale`, or the product overflows (WO P1-3). This is the SINGLE range-check source shared
    /// by `AcceptabilityCriteria` and the item risk-input mutation op — so the check never diverges.
    public func inRangeScore(likelihood: Int?, severity: Int?) -> Int? {
        guard let l = likelihood, let s = severity,
              (1...likelihoodScale).contains(l),
              (1...severityScale).contains(s) else { return nil }
        let (score, overflow) = l.multipliedReportingOverflow(by: s)
        return overflow ? nil : score
    }

    /// The band for an in-range likelihood × severity, or nil when out of range/overflow — so a
    /// range-invalid input never gets an auto-assigned risk level (nil=미평가).
    public func inRangeBand(likelihood: Int?, severity: Int?) -> RiskLevel? {
        inRangeScore(likelihood: likelihood, severity: severity).map(band(forScore:))
    }

    // MARK: - Format v1 wire

    /// Self-describing wire form; `formatVersion` is written into the blob AND checked against
    /// the stored `matrixFormatVersion` column so a version mismatch is caught either way.
    private struct Wire: Codable {
        var formatVersion: Int
        var likelihoodScale: Int
        var severityScale: Int
        var bands: [Band]
    }

    /// Encodes to the format-v1 JSON blob stored in `AssessmentCriteria.matrixData`.
    public func encoded() throws -> Data {
        try JSONEncoder().encode(Wire(
            formatVersion: 1,
            likelihoodScale: likelihoodScale,
            severityScale: severityScale,
            bands: bands))
    }

    /// Decodes + validates a stored blob. FAIL-CLOSED: every malformed condition throws a
    /// `CriteriaError`; nothing is silently defaulted.
    public static func decode(_ data: Data, formatVersion: Int) throws -> CriteriaMatrixSnapshot {
        guard formatVersion == 1 else { throw CriteriaError.unsupportedFormatVersion(formatVersion) }
        guard !data.isEmpty else { throw CriteriaError.emptyData }
        let wire: Wire
        do {
            wire = try JSONDecoder().decode(Wire.self, from: data)
        } catch {
            throw CriteriaError.corruptedData
        }
        guard wire.formatVersion == 1 else { throw CriteriaError.unsupportedFormatVersion(wire.formatVersion) }
        let snapshot = CriteriaMatrixSnapshot(
            likelihoodScale: wire.likelihoodScale,
            severityScale: wire.severityScale,
            bands: wire.bands)
        try snapshot.validate()
        return snapshot
    }

    /// Structural validation shared by decode (and re-checkable at start). Fail-closed on scale
    /// multiplication overflow — never crash (WO P1-3).
    public func validate() throws {
        guard likelihoodScale > 0, severityScale > 0 else { throw CriteriaError.nonPositiveScale }
        let (maxPossible, overflow) = likelihoodScale.multipliedReportingOverflow(by: severityScale)
        guard !overflow else { throw CriteriaError.scaleOverflow }
        guard !bands.isEmpty else { throw CriteriaError.emptyBands }
        for i in 1..<bands.count where bands[i].maxScore <= bands[i - 1].maxScore {
            throw CriteriaError.bandsNotAscending
        }
        guard let last = bands.last, last.maxScore >= maxPossible else { throw CriteriaError.maxScoreNotCovered }
    }
}
