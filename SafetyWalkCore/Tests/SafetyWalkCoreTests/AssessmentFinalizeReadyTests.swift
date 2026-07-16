import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2b §7 — 2b provides ONLY the finalize-READINESS predicate (no finalize transition —
// that lands in 2c/2d). Ready ⇔ ≥1 item, every item has a riskLevel AND a fully-confirmed
// decision (criteriaDecision + confirmedAt + confirmedBy), and the criteria exists, decodes,
// and is locked.

@Suite("AssessmentFinalization — readiness predicate boundaries")
struct AssessmentFinalizeReadyTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)

    /// Builds a fully finalize-ready assessment (one confirmed item + a locked criteria).
    private func readyAssessment(in ctx: ModelContext) throws -> RiskAssessment {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "현장", status: .planned)
        ctx.insert(ra)
        try AssessmentStart.start(ra, criteria: .makeDefault(usesFrequencySeverity: true), now: when, in: ctx)
        let item = RiskAssessmentItem(likelihood: 3, severity: 3, riskLevel: .high)
        item.riskAssessment = ra
        item.confirmCriteriaDecision(.exceedsThreshold, at: when, by: "홍길동")
        ctx.insert(item)
        ra.items = [item]
        try ctx.save()
        return ra
    }

    @Test func fullyConfirmedAssessmentIsReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        #expect(AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func noItemsIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.items = []
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func itemMissingRiskLevelIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.items?.first?.riskLevel = nil
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func itemWithUnconfirmedDecisionIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.items?.first?.clearCriteriaDecision()   // riskLevel stays, decision cleared
        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
    }

    @Test func itemMissingConfirmerIsNotReady() throws {
        let ctx = try makeContext()
        let ra = try readyAssessment(in: ctx)
        ra.items?.first?.decisionConfirmedBy = nil   // decision + time present, confirmer missing
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
}
