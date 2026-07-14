import Testing
import Foundation
import SafetyWalkCore

// MARK: - Risk matrix band derivation (frequency × severity, 3×3)

@Suite("RiskMatrixConfig — 3×3 band derivation")
struct RiskMatrixBandTests {

    let cfg = RiskMatrixConfig.threeByThree

    @Test func scaleIsThreeByThree() {
        #expect(cfg.likelihoodScale == 3)
        #expect(cfg.severityScale == 3)
    }

    @Test func scoreIsProduct() {
        #expect(cfg.score(likelihood: 3, severity: 2) == 6)
        #expect(cfg.score(likelihood: 1, severity: 1) == 1)
    }

    /// Every likelihood(1–3) × severity(1–3) combination → expected band.
    /// Owner decision: products {1,2,3,4,6,9}; ≤2 → low, 3–4 → medium, ≥6 → high.
    @Test func bandCoversAll3x3Combinations() {
        // rows = likelihood 1…3, cols = severity 1…3
        let expected: [[RiskLevel]] = [
            [.low, .low, .medium],    // likelihood 1 → scores 1, 2, 3
            [.low, .medium, .high],   // likelihood 2 → scores 2, 4, 6
            [.medium, .high, .high],  // likelihood 3 → scores 3, 6, 9
        ]
        for l in 1...3 {
            for s in 1...3 {
                let got = cfg.band(likelihood: l, severity: s)
                #expect(got == expected[l - 1][s - 1],
                        "likelihood \(l) × severity \(s) (score \(l * s)) should be \(expected[l - 1][s - 1]), got \(got)")
            }
        }
    }

    /// Band boundaries by raw score, including the impossible-in-3×3 score 5
    /// (documents boundary behaviour) and the no-input score 0.
    @Test func bandBoundariesByScore() {
        #expect(cfg.band(forScore: 0) == .low)   // no input yet
        #expect(cfg.band(forScore: 1) == .low)
        #expect(cfg.band(forScore: 2) == .low)
        #expect(cfg.band(forScore: 3) == .medium)
        #expect(cfg.band(forScore: 4) == .medium)
        #expect(cfg.band(forScore: 5) == .high)  // impossible in 3×3, > medium boundary
        #expect(cfg.band(forScore: 6) == .high)
        #expect(cfg.band(forScore: 9) == .high)
    }
}

// MARK: - Models (CloudKit-ready shape + method behaviour)

@Suite("RiskAssessment models")
struct RiskAssessmentModelTests {

    private let siteId = UUID()

    @Test func assessmentDefaultsAreCloudKitReady() {
        // SCHEMA_V3 §4.1: siteId·siteName·kind·method are required; the lifecycle starts at
        // .planned with every audit/record field nil (미기록, 교정 #3).
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: siteId, siteName: "1공장")
        #expect(ra.kind == .regular)
        #expect(ra.method == .frequencySeverity)
        #expect(ra.siteId == siteId)
        #expect(ra.siteName == "1공장")
        #expect(ra.assessorName == "")
        #expect(ra.note == nil)
        #expect(ra.linkedInspectionId == nil)
        #expect(ra.status == .planned)
        #expect(ra.scheduledAt == nil)
        #expect(ra.assessedAt == nil)          // nil=미기록(교정 #3)
        #expect(ra.finalizedAt == nil)
        #expect(ra.workerRepStatus == nil)     // nil=미기록
        #expect(ra.items?.isEmpty == true)
        #expect(ra.participants?.isEmpty == true)
        #expect(ra.criteria == nil)
    }

    @Test func assessmentInitSetsValues() {
        let ra = RiskAssessment(kind: .initial, method: .threeLevel,
                                siteId: siteId, siteName: "1공장", assessorName: "홍길동")
        #expect(ra.kind == .initial)
        #expect(ra.method == .threeLevel)
        #expect(ra.siteId == siteId)
        #expect(ra.siteName == "1공장")
        #expect(ra.assessorName == "홍길동")
    }

    @Test func itemDefaultsAreUnassessed() {
        // SCHEMA_V3 교정 #3: a fresh item is 미평가 — riskLevel/criteriaDecision are nil, never
        // auto-Low/기준내. The old per-item improvement fields now live on CorrectiveAction.
        let item = RiskAssessmentItem()
        #expect(item.taskDescription == "")
        #expect(item.hazardDescription == "")
        #expect(item.currentControls == nil)
        #expect(item.likelihood == nil)
        #expect(item.severity == nil)
        #expect(item.riskLevel == nil)
        #expect(item.criteriaDecision == nil)
        #expect(item.decisionConfirmedAt == nil)
        #expect(item.isAssessed == false)
        #expect(item.linkedHazardId == nil)
        #expect(item.correctiveActions?.isEmpty == true)
    }

    /// 3단계 (threeLevel): user sets riskLevel directly; likelihood/severity stay nil.
    @Test func threeLevelPassThroughPreservesRiskLevel() {
        for level in [RiskLevel.low, .medium, .high] {
            let item = RiskAssessmentItem(riskLevel: level)
            #expect(item.riskLevel == level)
            #expect(item.likelihood == nil)
            #expect(item.severity == nil)
        }
    }

    /// 빈도×강도 (frequencySeverity): riskLevel is the derived band for the inputs.
    @Test func frequencySeverityDerivesRiskLevel() {
        let cfg = RiskMatrixConfig.threeByThree
        let l = 2, s = 3                       // score 6 → high
        let derived = cfg.band(likelihood: l, severity: s)
        let item = RiskAssessmentItem(likelihood: l, severity: s, riskLevel: derived)
        #expect(item.likelihood == 2)
        #expect(item.severity == 3)
        #expect(item.riskLevel == .high)
    }
}

// MARK: - WO-2b: 4 methods + sortOrder

@Suite("RiskAssessmentMethod — 4 methods (WO-2b)")
struct RiskAssessmentMethodTests {

    @Test func allFourMethodsExist() {
        let all = RiskAssessmentMethod.allCases
        #expect(all.count == 4)
        #expect(all.contains(.checklist))
        #expect(all.contains(.jsa))
    }

    @Test func riskInputClassification() {
        // direct 상/중/하
        #expect(RiskAssessmentMethod.threeLevel.usesFrequencySeverity == false)
        #expect(RiskAssessmentMethod.checklist.usesFrequencySeverity == false)
        // likelihood × severity
        #expect(RiskAssessmentMethod.frequencySeverity.usesFrequencySeverity == true)
        #expect(RiskAssessmentMethod.jsa.usesFrequencySeverity == true)
    }
}

@Suite("RiskAssessmentItem — sortOrder (WO-2b)")
struct RiskAssessmentItemSortOrderTests {

    @Test func sortOrderDefaultsToZero() {
        #expect(RiskAssessmentItem(riskLevel: .low).sortOrder == 0)   // CloudKit-safe default
    }

    @Test func sortOrderIsSettable() {
        #expect(RiskAssessmentItem(riskLevel: .low, sortOrder: 3).sortOrder == 3)
    }
}
