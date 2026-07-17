import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2c — the atomic 개선조치(CorrectiveAction) 편집 ops: add / update / remove /
// confirmEffectiveness. Each validates fail-closed (빈 조치 = 감소대책 공백 거부), persists with a
// store+memory restore on commit failure (AssessmentDecision 패턴), and keeps the 효과확인 invariants:
// a substantive edit (measure/status/implementedAt/postRiskLevel) invalidates a prior 효과확인, while a
// non-substantive edit keeps it (SCHEMA_V3 §4·§4.1, LEGAL_2_ARCH §1.1).

@Suite("CorrectiveActionEditing — atomic 1:N ops (LEGAL-2c)")
struct CorrectiveActionEditingTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true) // threshold 2

    /// A saved inProgress assessment (locked criteria) with one confirmed 기준 초과 item (2×2 → 4 → medium).
    private func startedAssessment(in ctx: ModelContext) throws -> (RiskAssessment, RiskAssessmentItem) {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "현장", status: .planned)
        ctx.insert(ra)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium) // score 4 → exceeds@2
        item.riskAssessment = ra
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        ctx.insert(item)
        ra.items = [item]
        try ctx.save()
        return (ra, item)
    }

    // MARK: - add

    @Test func addRejectsBlankMeasure() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        #expect(throws: CorrectiveActionError.emptyMeasure) {
            try CorrectiveActionEditing.add(to: item, in: ra, measure: "   ", at: when, context: ctx)
        }
        #expect((item.correctiveActions ?? []).isEmpty)
    }

    @Test func addPersistsAndLinks() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(
            to: item, in: ra, measure: "난간 설치", responsibleName: "김안전",
            at: when.addingTimeInterval(60), context: ctx)
        #expect(action.measure == "난간 설치")
        #expect(action.item === item)
        #expect((item.correctiveActions ?? []).contains { $0 === action })
        #expect(ra.updatedAt == when.addingTimeInterval(60))
        let fresh = ModelContext(ctx.container)
        #expect(try fresh.fetch(FetchDescriptor<CorrectiveAction>()).count == 1)
    }

    /// 1:N 보존: two actions under one item both persist (never collapsed to one).
    @Test func twoActionsBothPersist() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "조치1", at: when, context: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "조치2", at: when, context: ctx)
        #expect((item.correctiveActions ?? []).count == 2)
        let fresh = ModelContext(ctx.container)
        #expect(try fresh.fetch(FetchDescriptor<CorrectiveAction>()).count == 2)
    }

    @Test func addRejectsWhenCancelled() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        ra.status = .cancelled                 // cancelled = read-only
        #expect(throws: CorrectiveActionError.assessmentNotEditable) {
            try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)
        }
    }

    @Test func addAllowedWhenFinalized() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        ra.status = .finalized                 // CorrectiveAction stays editable after finalized (lock timing)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "점검 강화", at: when, context: ctx)
        #expect((item.correctiveActions ?? []).contains { $0 === action })
    }

    @Test func addRejectsItemNotInAssessment() throws {
        let ctx = try makeContext()
        let (ra, _) = try startedAssessment(in: ctx)
        let stray = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium)
        ctx.insert(stray)
        #expect(throws: CorrectiveActionError.itemNotInAssessment) {
            try CorrectiveActionEditing.add(to: stray, in: ra, measure: "난간", at: when, context: ctx)
        }
    }

    /// A failed commit restores BOTH the store and the in-memory state — no phantom action.
    @Test func addFailedCommitRestoresStoreAndMemory() throws {
        struct CommitFailed: Error {}
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let priorUpdatedAt = ra.updatedAt
        #expect(throws: CommitFailed.self) {
            try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치",
                                            at: when.addingTimeInterval(99), context: ctx,
                                            commit: { throw CommitFailed() })
        }
        #expect((item.correctiveActions ?? []).isEmpty)      // memory restored
        #expect(ra.updatedAt == priorUpdatedAt)
        let fresh = ModelContext(ctx.container)
        #expect(try fresh.fetch(FetchDescriptor<CorrectiveAction>()).isEmpty)  // store restored
    }

    // MARK: - update / 효과확인 무효화

    /// A SUBSTANTIVE edit (postRiskLevel) invalidates a recorded 효과확인 (효과확인 무효화).
    @Test func substantiveUpdateInvalidatesEffectiveness() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(
            to: item, in: ra, measure: "난간 설치", status: .completed,
            implementedAt: when, postRiskLevel: .low, at: when, context: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)
        #expect(action.effectivenessResult == .effective)

        try CorrectiveActionEditing.update(
            action, in: ra, measure: "난간 설치", status: .completed,
            implementedAt: when, postRiskLevel: .medium, at: when.addingTimeInterval(10), context: ctx)
        #expect(action.effectivenessResult == nil)
        #expect(action.confirmedBy == nil)
        #expect(action.effectivenessConfirmedAt == nil)
    }

    /// A NON-substantive edit (responsibleName only) keeps the 효과확인.
    @Test func nonSubstantiveUpdateKeepsEffectiveness() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(
            to: item, in: ra, measure: "난간 설치", status: .completed,
            implementedAt: when, postRiskLevel: .low, at: when, context: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)

        try CorrectiveActionEditing.update(
            action, in: ra, measure: "난간 설치", responsibleName: "새담당", status: .completed,
            implementedAt: when, postRiskLevel: .low, at: when.addingTimeInterval(10), context: ctx)
        #expect(action.effectivenessResult == .effective)
        #expect(action.responsibleName == "새담당")
    }

    @Test func updateRejectsBlankMeasure() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)
        #expect(throws: CorrectiveActionError.emptyMeasure) {
            try CorrectiveActionEditing.update(action, in: ra, measure: "  ", status: .notStarted, at: when, context: ctx)
        }
    }

    /// A failed commit restores the edited fields AND the invalidated 효과확인.
    @Test func updateFailedCommitRestoresFieldsAndEffectiveness() throws {
        struct CommitFailed: Error {}
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(
            to: item, in: ra, measure: "난간 설치", status: .completed,
            implementedAt: when, postRiskLevel: .low, at: when, context: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)

        #expect(throws: CommitFailed.self) {
            try CorrectiveActionEditing.update(
                action, in: ra, measure: "변경", status: .inProgress,
                implementedAt: nil, postRiskLevel: .high, at: when.addingTimeInterval(5),
                context: ctx, commit: { throw CommitFailed() })
        }
        #expect(action.measure == "난간 설치")
        #expect(action.status == .completed)
        #expect(action.postRiskLevel == .low)
        #expect(action.effectivenessResult == .effective)
        #expect(action.confirmedBy == "김확인")
    }

    // MARK: - confirmEffectiveness preconditions (이행일·개선후위험도·확인자)

    @Test func confirmEffectivenessRejectsWithoutImplementedAt() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간", postRiskLevel: .low, at: when, context: ctx)
        #expect(throws: CorrectiveActionError.effectivenessPreconditionUnmet) {
            try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)
        }
    }

    @Test func confirmEffectivenessRejectsWithoutPostRiskLevel() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간", implementedAt: when, at: when, context: ctx)
        #expect(throws: CorrectiveActionError.effectivenessPreconditionUnmet) {
            try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)
        }
    }

    @Test func confirmEffectivenessRejectsBlankConfirmer() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간", implementedAt: when, postRiskLevel: .low, at: when, context: ctx)
        #expect(throws: CorrectiveActionError.emptyConfirmer) {
            try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "   ", at: when, context: ctx)
        }
    }

    @Test func confirmEffectivenessRecordsAndPersists() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간", implementedAt: when, postRiskLevel: .low, at: when, context: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(
            action, in: ra, result: .partiallyEffective, by: "김확인", at: when.addingTimeInterval(30), context: ctx)
        #expect(action.effectivenessResult == .partiallyEffective)
        #expect(action.confirmedBy == "김확인")
        #expect(action.effectivenessConfirmedAt == when.addingTimeInterval(30))
        #expect(action.isEffectivenessComplete)
        #expect(!action.isEffectivelyResolved)   // partial ≠ effective → 미종결
    }

    // MARK: - remove

    @Test func removeDeletesActionAndPreservesSiblings() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let a1 = try CorrectiveActionEditing.add(to: item, in: ra, measure: "조치1", at: when, context: ctx)
        let a2 = try CorrectiveActionEditing.add(to: item, in: ra, measure: "조치2", at: when, context: ctx)
        try CorrectiveActionEditing.remove(a1, in: ra, at: when, context: ctx)
        #expect((item.correctiveActions ?? []).contains { $0 === a2 })
        #expect(!(item.correctiveActions ?? []).contains { $0 === a1 })
        let fresh = ModelContext(ctx.container)
        #expect(try fresh.fetch(FetchDescriptor<CorrectiveAction>()).count == 1)
    }
}
