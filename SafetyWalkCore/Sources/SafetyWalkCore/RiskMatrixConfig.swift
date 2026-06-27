import Foundation

/// Frequency × severity risk matrix, expressed as DATA (not hard-coded if/else).
/// A score (likelihood × severity) maps to a `RiskLevel` band via ordered
/// boundaries. To move to a 5×5 matrix later, only the config values change —
/// no logic edits (CLAUDE.md: "Templates/matrix in data").
public struct RiskMatrixConfig: Equatable {

    /// One band boundary: every score ≤ `maxScore` (and above the previous band)
    /// resolves to `level`. Bands are ordered ascending by `maxScore`; the last
    /// band must cover the maximum possible score (use `Int.max`).
    public struct Band: Equatable {
        public let maxScore: Int
        public let level: RiskLevel
        public init(maxScore: Int, level: RiskLevel) {
            self.maxScore = maxScore
            self.level = level
        }
    }

    public let likelihoodScale: Int
    public let severityScale: Int
    public let bands: [Band]

    public init(likelihoodScale: Int, severityScale: Int, bands: [Band]) {
        self.likelihoodScale = likelihoodScale
        self.severityScale = severityScale
        self.bands = bands
    }

    /// Raw risk score = likelihood × severity.
    public func score(likelihood: Int, severity: Int) -> Int {
        likelihood * severity
    }

    /// Resolve the 위험성 수준 (band) for a given score — first band whose
    /// `maxScore` the score does not exceed.
    public func band(forScore score: Int) -> RiskLevel {
        for band in bands where score <= band.maxScore {
            return band.level
        }
        return bands.last?.level ?? .high
    }

    /// Convenience: band directly from likelihood × severity inputs.
    public func band(likelihood: Int, severity: Int) -> RiskLevel {
        band(forScore: score(likelihood: likelihood, severity: severity))
    }

    /// Default 3×3 (WO-2 owner decision): products are {1,2,3,4,6,9};
    /// score 1–2 → 하(low), 3–4 → 중(medium), 6+ → 상(high).
    public static let threeByThree = RiskMatrixConfig(
        likelihoodScale: 3,
        severityScale: 3,
        bands: [
            Band(maxScore: 2, level: .low),
            Band(maxScore: 4, level: .medium),
            Band(maxScore: .max, level: .high),
        ]
    )
}
