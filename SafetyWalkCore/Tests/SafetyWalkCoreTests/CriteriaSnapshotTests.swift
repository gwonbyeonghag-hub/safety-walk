import Testing
import Foundation
import SafetyWalkCore

// WO LEGAL-2b — the locked criteria matrix snapshot (format v1). Round-trip preserves the
// matrix; any malformed blob is FAIL-CLOSED (throws, never silently substitutes a default).
// Expected bands come from the WO doc's 3×3 snapshot: 1~2 low, 3~4 medium, 5~9 high.

@Suite("CriteriaMatrixSnapshot — format v1 codec")
struct CriteriaMatrixCodecTests {

    /// Round trip: encode → decode reproduces the same snapshot.
    @Test func roundTripPreservesSnapshot() throws {
        let original = CriteriaMatrixSnapshot.threeByThree
        let data = try original.encoded()
        let decoded = try CriteriaMatrixSnapshot.decode(data, formatVersion: 1)
        #expect(decoded == original)
        #expect(decoded.likelihoodScale == 3)
        #expect(decoded.severityScale == 3)
        #expect(decoded.maxScore == 9)
    }

    /// WO §6: the snapshot's 3×3 is value-copied from `RiskMatrixConfig.threeByThree` (single
    /// source), with the `.max` top boundary normalized to the real max score (9) — and every
    /// possible 3×3 input resolves to the SAME RiskLevel in both representations.
    @Test func snapshotMatchesRiskMatrixConfigForAll3x3() {
        let config = RiskMatrixConfig.threeByThree
        let snapshot = CriteriaMatrixSnapshot.threeByThree
        #expect(snapshot.likelihoodScale == config.likelihoodScale)
        #expect(snapshot.severityScale == config.severityScale)
        #expect(snapshot.bands.last?.maxScore == 9)   // .max normalized to the real max score
        for l in 1...3 {
            for s in 1...3 {
                #expect(snapshot.band(forScore: l * s) == config.band(likelihood: l, severity: s),
                        "l\(l)×s\(s): snapshot \(snapshot.band(forScore: l * s)) vs config \(config.band(likelihood: l, severity: s))")
            }
        }
    }

    /// The default 3×3 resolves each raw score to the WO-documented band.
    @Test func defaultThreeByThreeBands() {
        let m = CriteriaMatrixSnapshot.threeByThree
        #expect(m.band(forScore: 1) == .low)
        #expect(m.band(forScore: 2) == .low)
        #expect(m.band(forScore: 3) == .medium)
        #expect(m.band(forScore: 4) == .medium)
        #expect(m.band(forScore: 5) == .high)
        #expect(m.band(forScore: 6) == .high)
        #expect(m.band(forScore: 9) == .high)
    }
}

@Suite("CriteriaMatrixSnapshot — fail-closed decode")
struct CriteriaMatrixFailClosedTests {

    private let goodData: Data = try! CriteriaMatrixSnapshot.threeByThree.encoded()

    @Test func emptyDataThrows() {
        #expect(throws: CriteriaError.emptyData) {
            try CriteriaMatrixSnapshot.decode(Data(), formatVersion: 1)
        }
    }

    @Test func unsupportedFormatVersionThrows() {
        #expect(throws: CriteriaError.unsupportedFormatVersion(2)) {
            try CriteriaMatrixSnapshot.decode(goodData, formatVersion: 2)
        }
    }

    @Test func corruptedJSONThrows() {
        let junk = Data("not json at all".utf8)
        #expect(throws: CriteriaError.corruptedData) {
            try CriteriaMatrixSnapshot.decode(junk, formatVersion: 1)
        }
    }

    @Test func nonPositiveScaleThrows() throws {
        let bad = CriteriaMatrixSnapshot(
            likelihoodScale: 0, severityScale: 3,
            bands: [.init(maxScore: 9, level: .high)])
        let data = try bad.encoded()
        #expect(throws: CriteriaError.nonPositiveScale) {
            try CriteriaMatrixSnapshot.decode(data, formatVersion: 1)
        }
    }

    @Test func duplicateOrDescendingBandsThrow() throws {
        // duplicate boundary
        let dup = CriteriaMatrixSnapshot(
            likelihoodScale: 3, severityScale: 3,
            bands: [.init(maxScore: 2, level: .low),
                    .init(maxScore: 2, level: .medium),
                    .init(maxScore: 9, level: .high)])
        #expect(throws: CriteriaError.bandsNotAscending) {
            try CriteriaMatrixSnapshot.decode(dup.encoded(), formatVersion: 1)
        }
        // descending boundary
        let rev = CriteriaMatrixSnapshot(
            likelihoodScale: 3, severityScale: 3,
            bands: [.init(maxScore: 4, level: .medium),
                    .init(maxScore: 2, level: .low),
                    .init(maxScore: 9, level: .high)])
        #expect(throws: CriteriaError.bandsNotAscending) {
            try CriteriaMatrixSnapshot.decode(rev.encoded(), formatVersion: 1)
        }
    }

    @Test func maxScoreNotCoveredThrows() throws {
        // last band tops out at 4 but 3×3 can reach 9 → incomplete range.
        let short = CriteriaMatrixSnapshot(
            likelihoodScale: 3, severityScale: 3,
            bands: [.init(maxScore: 2, level: .low),
                    .init(maxScore: 4, level: .medium)])
        #expect(throws: CriteriaError.maxScoreNotCovered) {
            try CriteriaMatrixSnapshot.decode(short.encoded(), formatVersion: 1)
        }
    }

    @Test func emptyBandsThrow() throws {
        let none = CriteriaMatrixSnapshot(likelihoodScale: 3, severityScale: 3, bands: [])
        #expect(throws: CriteriaError.emptyBands) {
            try CriteriaMatrixSnapshot.decode(none.encoded(), formatVersion: 1)
        }
    }
}
