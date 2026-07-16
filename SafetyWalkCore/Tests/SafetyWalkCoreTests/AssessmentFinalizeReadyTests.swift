import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2b §4 — the finalize-READINESS predicate (2b ships this only; no finalize transition).
// Ready ⇔ status .inProgress · locked criteria that FULLY decodes (matrix + threshold) · ≥1 item ·
// every item has risk input AND a CURRENT confirmation (three fields + stored decision == the
// suggestion recomputed now). planned/finalized/cancelled, a stale decision, or an invalid stored
// threshold all make it false.

@Suite("AssessmentFinalization — readiness predicate (§4)")
struct AssessmentFinalizeReadyTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true) // threshold 2

    /// Builds a fully finalize-ready assessment: inProgress + locked criteria + one CURRENT item.
    private func readyAssessment(in ctx: ModelContext) throws -> RiskAssessment {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "현장", status: .planned)
        ctx.insert(ra)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        let item = RiskAssessmentItem(likelihood: 3, severity: 3, riskLevel: .high) // score 9 → exceeds@2
        item.riskAssessment = ra
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        ctx.insert(item)
        ra.items = [item]
        try ctx.save()
        return ra
    }

    @Test func fullyConfirmedInProgressIsReady() throws {
        let ctx = try makeContext()
        #expect(AssessmentFinalization.isReadyToFinalize(try readyAssessment(in: ctx)))
    }

    /// Only .inProgress is ready — planned/finalized/cancelled are not.
    @Test func nonInProgressIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        for status in [AssessmentStatus.planned, .finalized, .cancelled] {
            ra.status = status
            #expect(!AssessmentFinalization.isReadyToFinalize(ra), "status \(status) must not be ready")
        }
        ra.status = .inProgress
        #expect(AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func noItemsIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.items = []
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func itemMissingRiskInputIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.items?.first?.riskLevel = nil
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func staleDecisionIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        // Risk drops from 9 (exceeds) to 1 (within) → stored 'exceeds' no longer matches → stale.
        ra.items?.first?.likelihood = 1
        ra.items?.first?.severity = 1
        ra.items?.first?.riskLevel = .low
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func itemMissingConfirmerIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.items?.first?.decisionConfirmedBy = nil
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func missingCriteriaIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.criteria = nil
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func unlockedCriteriaIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.criteria?.lockedAt = nil
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func corruptCriteriaSnapshotIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.criteria?.matrixData = Data("garbage".utf8)   // fail-closed → not ready
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }

    /// A stored criteria whose threshold is outside the allowed set fails the full decode → not ready.
    @Test func invalidStoredThresholdIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.criteria?.acceptabilityThreshold = 3   // not in {2,4} for score → decode fails
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }
}
