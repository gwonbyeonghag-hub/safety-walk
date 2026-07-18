import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2b P1-1 — the atomic 기준 결정 확인 op: guards status/ownership/criteria, decodes the
// locked criteria itself, records the computed decision + updatedAt in one step, and on a commit
// failure rolls back the STORE and restores the in-memory instances (no phantom confirmation).

@Suite("AssessmentDecision — atomic confirm (P1-1)")
struct AssessmentDecisionTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)

    /// A saved inProgress assessment (locked criteria) with one consistent item (2×2 → medium).
    private func startedAssessment(in ctx: ModelContext) throws -> (RiskAssessment, RiskAssessmentItem) {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "현장")
        ctx.insert(ra)
        try AssessmentStart.start(ra, criteria: .makeDefault(usesFrequencySeverity: true), now: when, in: ctx)
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium) // score 4 → exceeds@2
        item.riskAssessment = ra
        ctx.insert(item)
        ra.items = [item]
        try ctx.save()
        return (ra, item)
    }

    @Test func confirmRecordsAndPersists() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        try AssessmentDecision.confirm(item: item, in: ra, by: "홍길동", at: when, context: ctx)
        #expect(item.criteriaDecision == .exceedsThreshold)
        #expect(item.decisionConfirmedBy == "홍길동")
        #expect(ra.updatedAt == when)
        #expect(item.hasCurrentCriteriaDecision(under: .makeDefault(usesFrequencySeverity: true)))
    }

    @Test func rejectsWhenNotInProgress() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        ra.status = .finalized
        #expect(throws: AssessmentDecisionError.notInProgress) {
            try AssessmentDecision.confirm(item: item, in: ra, by: "홍길동", at: when, context: ctx)
        }
    }

    @Test func rejectsItemNotInAssessment() throws {
        let ctx = try makeContext()
        let (ra, _) = try startedAssessment(in: ctx)
        let stray = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium)
        ctx.insert(stray)
        #expect(throws: AssessmentDecisionError.itemNotInAssessment) {
            try AssessmentDecision.confirm(item: stray, in: ra, by: "홍길동", at: when, context: ctx)
        }
    }

    @Test func rejectsWhenCriteriaMissing() throws {
        let ctx = try makeContext()
        // A hand-built inProgress assessment WITHOUT a locked criteria.
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "현장")
        // WO LEGAL-2d §5: 생성자로는 .planned 만 만들 수 있다. 잠긴 기준 없는 inProgress 는 비정상
        // 상태이므로 Core 내부 setter 로 직접 구성한다(@testable) — 앱 코드로는 도달 불가.
        ra.status = .inProgress
        ctx.insert(ra)
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium)
        item.riskAssessment = ra
        ctx.insert(item)
        ra.items = [item]
        try ctx.save()
        #expect(throws: AssessmentDecisionError.criteriaMissing) {
            try AssessmentDecision.confirm(item: item, in: ra, by: "홍길동", at: when, context: ctx)
        }
    }

    /// A failed commit restores BOTH the store and the in-memory instances to the pre-confirm state.
    @Test func failedCommitRestoresStoreAndMemory() throws {
        struct CommitFailed: Error {}
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let priorUpdatedAt = ra.updatedAt   // == when (from start), distinct from the confirm date below
        let confirmDate = when.addingTimeInterval(3600)

        #expect(throws: CommitFailed.self) {
            try AssessmentDecision.confirm(item: item, in: ra, by: "홍길동", at: confirmDate,
                                           context: ctx, commit: { throw CommitFailed() })
        }
        // In-memory restored (would read the confirm state if the restore hadn't run).
        #expect(item.criteriaDecision == nil)
        #expect(item.decisionConfirmedAt == nil)
        #expect(item.decisionConfirmedBy == nil)
        #expect(ra.updatedAt == priorUpdatedAt)
        // Store restored: a fresh context on the same container sees no confirmed decision.
        let fresh = ModelContext(ctx.container)
        let storedItem = try #require(try fresh.fetch(FetchDescriptor<RiskAssessmentItem>()).first)
        #expect(storedItem.criteriaDecision == nil)
    }
}
