import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2b §5 — starting an assessment (planned → inProgress) is ONE failable, atomic
// operation shared by both UI paths: validate criteria → create & lock a value-copied
// AssessmentCriteria → link inverse → stamp assessedAt/updatedAt → flip status → save. A
// non-planned restart and re-writing a locked criteria are both forbidden; a failed start
// leaves no partial state.

@Suite("AssessmentStart — atomic start (planned → inProgress)")
struct AssessmentStartTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private func plannedAssessment(in ctx: ModelContext) -> RiskAssessment {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "현장")
        ctx.insert(ra)
        return ra
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func startLocksCriteriaAndFlipsStatus() throws {
        let ctx = try makeContext()
        let ra = plannedAssessment(in: ctx)
        let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true) // threshold 2

        try AssessmentStart.start(ra, criteria: criteria, now: now, in: ctx)

        #expect(ra.status == .inProgress)
        #expect(ra.assessedAt == now)
        #expect(ra.updatedAt == now)

        let ac = try #require(ra.criteria)
        #expect(ac.lockedAt == now)                       // inProgress 잠금
        #expect(ac.acceptabilityThreshold == 2)
        #expect(ac.matrixFormatVersion == 1)
        #expect(ac.riskAssessment === ra)                 // inverse wired
        // Value-copied snapshot decodes back to the 3×3 matrix.
        let decoded = try CriteriaMatrixSnapshot.decode(ac.matrixData, formatVersion: ac.matrixFormatVersion)
        #expect(decoded == .threeByThree)
    }

    @Test func startPersistsTheCriteria() throws {
        let ctx = try makeContext()
        let ra = plannedAssessment(in: ctx)
        try AssessmentStart.start(ra, criteria: .makeDefault(usesFrequencySeverity: true), now: now, in: ctx)
        // Persisted: a fresh fetch finds exactly one locked criteria.
        let stored = try ctx.fetch(FetchDescriptor<AssessmentCriteria>())
        #expect(stored.count == 1)
        #expect(stored.first?.lockedAt == now)
    }

    /// 재시작 금지: a non-planned assessment cannot be started again — and stays untouched.
    @Test func restartOfNonPlannedIsRejected() throws {
        let ctx = try makeContext()
        let ra = plannedAssessment(in: ctx)
        try AssessmentStart.start(ra, criteria: .makeDefault(usesFrequencySeverity: true), now: now, in: ctx)
        let lockedAtFirstStart = ra.criteria?.lockedAt

        let later = now.addingTimeInterval(3600)
        #expect(throws: AssessmentStartError.notPlanned) {
            try AssessmentStart.start(ra, criteria: .makeDefault(usesFrequencySeverity: true), now: later, in: ctx)
        }
        // Unchanged: still one criteria, still the original lock time.
        #expect(ra.criteria?.lockedAt == lockedAtFirstStart)
        #expect(try ctx.fetch(FetchDescriptor<AssessmentCriteria>()).count == 1)
    }

    /// 잠긴 기준 재작성 금지: a planned assessment that somehow already carries a criteria is rejected.
    @Test func startRejectsPreexistingCriteria() throws {
        let ctx = try makeContext()
        let ra = plannedAssessment(in: ctx)
        let stale = AssessmentCriteria(matrixData: try CriteriaMatrixSnapshot.threeByThree.encoded(),
                                       matrixFormatVersion: 1, acceptabilityThreshold: 4)
        ctx.insert(stale)
        ra.criteria = stale

        #expect(throws: AssessmentStartError.criteriaAlreadyLocked) {
            try AssessmentStart.start(ra, criteria: .makeDefault(usesFrequencySeverity: true), now: now, in: ctx)
        }
        #expect(ra.status == .planned)                    // no partial flip
        #expect(ra.assessedAt == nil)
    }

    /// WO §8 REAL rollback: when the commit fails, start's real mutations (criteria insert, status
    /// flip, timestamps) are rolled back via a real `context.rollback()` to the pre-start persisted
    /// state — no partial commit — and the error rethrows. Only the commit throw is injected
    /// (SwiftData can't be made to throw a catchable save() on these unique-free models).
    @Test func failedCommitRollsBackToPreStartState() throws {
        struct CommitFailed: Error {}
        let ctx = try makeContext()
        let ra = plannedAssessment(in: ctx)
        try ctx.save()                    // persist the .planned state as the rollback target

        #expect(throws: CommitFailed.self) {
            try AssessmentStart.start(ra, criteria: .makeDefault(usesFrequencySeverity: true),
                                      now: now, in: ctx, commit: { throw CommitFailed() })
        }
        // Rolled back to the pre-start persisted state — every mutation reverted.
        #expect(ra.status == .planned)
        #expect(ra.criteria == nil)
        #expect(ra.assessedAt == nil)
        #expect(try ctx.fetch(FetchDescriptor<AssessmentCriteria>()).isEmpty)
    }

    /// 실패 시 부분 상태 없음: a rejected start does not insert a criteria or mutate the assessment.
    @Test func rejectedStartLeavesNoPartialState() throws {
        let ctx = try makeContext()
        let ra = plannedAssessment(in: ctx)
        ra.status = .inProgress                           // force the guard to fire
        #expect(throws: AssessmentStartError.notPlanned) {
            try AssessmentStart.start(ra, criteria: .makeDefault(usesFrequencySeverity: true), now: now, in: ctx)
        }
        #expect(ra.criteria == nil)
        #expect(ra.assessedAt == nil)
        #expect(try ctx.fetch(FetchDescriptor<AssessmentCriteria>()).isEmpty)
    }
}
