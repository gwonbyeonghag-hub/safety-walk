import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2c (반송 2차) — the atomic 개선조치 편집 ops with the STATUS-DRIVEN effectiveness lifecycle:
// 최초 생성은 항상 .notStarted(이행일·개선후위험도·효과확인 비어 있음); .completed 저장은 implementedAt
// 필수; 완료→미완료 되돌림은 이행일·개선후위험도·효과확인을 Core가 원자적으로 초기화; 효과확인은
// .completed에서만 가능. 모든 mutating op는 커밋 실패 시 store+memory를 복원한다.

@Suite("CorrectiveActionEditing — status-driven lifecycle (LEGAL-2c 2차)")
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

    /// Adds a plan (.notStarted) then drives it to .completed with 이행일·개선후위험도 (the only path to
    /// a completed action, since `add` never creates one).
    private func completedAction(_ item: RiskAssessmentItem, in ra: RiskAssessment,
                                 postRisk: RiskLevel = .low, in ctx: ModelContext) throws -> CorrectiveAction {
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)
        try CorrectiveActionEditing.update(action, in: ra, measure: "난간 설치", status: .completed,
                                           implementedAt: when, postRiskLevel: postRisk, at: when, context: ctx)
        return action
    }

    // MARK: - add (항상 .notStarted)

    @Test func addRejectsBlankMeasure() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        #expect(throws: CorrectiveActionError.emptyMeasure) {
            try CorrectiveActionEditing.add(to: item, in: ra, measure: "   ", at: when, context: ctx)
        }
        #expect((item.correctiveActions ?? []).isEmpty)
    }

    @Test func addCreatesNotStartedEmptyAction() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치",
                                                     responsibleName: "김안전", at: when, context: ctx)
        #expect(action.status == .notStarted)          // 최초 생성 = .notStarted
        #expect(action.implementedAt == nil)
        #expect(action.postRiskLevel == nil)
        #expect(action.effectivenessResult == nil)
        #expect(action.measure == "난간 설치")
        #expect((item.correctiveActions ?? []).contains { $0 === action })
        let fresh = ModelContext(ctx.container)
        #expect(try fresh.fetch(FetchDescriptor<CorrectiveAction>()).count == 1)
    }

    @Test func twoActionsBothPersist() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "조치1", at: when, context: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "조치2", at: when, context: ctx)
        #expect((item.correctiveActions ?? []).count == 2)
    }

    @Test func addRejectsWhenCancelled() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        ra.status = .cancelled
        #expect(throws: CorrectiveActionError.assessmentNotEditable) {
            try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)
        }
    }

    @Test func addAllowedWhenFinalized() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        ra.status = .finalized
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
        #expect((item.correctiveActions ?? []).isEmpty)
        #expect(ra.updatedAt == priorUpdatedAt)
        let fresh = ModelContext(ctx.container)
        #expect(try fresh.fetch(FetchDescriptor<CorrectiveAction>()).isEmpty)
    }

    // MARK: - update / 상태 전이

    @Test func updateRejectsBlankMeasure() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)
        #expect(throws: CorrectiveActionError.emptyMeasure) {
            try CorrectiveActionEditing.update(action, in: ra, measure: "  ", status: .notStarted, at: when, context: ctx)
        }
    }

    @Test func completedRequiresImplementedAt() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)
        #expect(throws: CorrectiveActionError.completedRequiresImplementedAt) {
            try CorrectiveActionEditing.update(action, in: ra, measure: "난간 설치", status: .completed,
                                               implementedAt: nil, postRiskLevel: .low, at: when, context: ctx)
        }
    }

    @Test func completedRecordsImplementation() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try completedAction(item, in: ra, in: ctx)
        #expect(action.status == .completed)
        #expect(action.implementedAt == when)
        #expect(action.postRiskLevel == .low)
    }

    /// implementedAt·postRiskLevel are completed-only: passing them with a non-completed status
    /// leaves them nil (status·이행일 컨트롤이 모순된 값을 만들 수 없다).
    @Test func nonCompletedStatusStripsImplementationFields() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try completedAction(item, in: ra, in: ctx)
        try CorrectiveActionEditing.update(action, in: ra, measure: "난간 설치", status: .inProgress,
                                           implementedAt: when, postRiskLevel: .low, at: when, context: ctx)
        #expect(action.status == .inProgress)
        #expect(action.implementedAt == nil)
        #expect(action.postRiskLevel == nil)
    }

    /// Reverting a completed+confirmed action to .notStarted clears 이행일·개선후위험도·효과확인.
    @Test func revertingCompletedClearsImplementationAndEffectiveness() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try completedAction(item, in: ra, in: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)
        #expect(action.effectivenessResult == .effective)

        try CorrectiveActionEditing.update(action, in: ra, measure: "난간 설치", status: .notStarted, at: when.addingTimeInterval(10), context: ctx)
        #expect(action.status == .notStarted)
        #expect(action.implementedAt == nil)
        #expect(action.postRiskLevel == nil)
        #expect(action.effectivenessResult == nil)
        #expect(action.confirmedBy == nil)
        #expect(action.effectivenessConfirmedAt == nil)
    }

    @Test func substantiveUpdateInvalidatesEffectiveness() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try completedAction(item, in: ra, in: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)
        // change postRiskLevel while still completed → effectiveness reset
        try CorrectiveActionEditing.update(action, in: ra, measure: "난간 설치", status: .completed,
                                           implementedAt: when, postRiskLevel: .medium, at: when.addingTimeInterval(10), context: ctx)
        #expect(action.effectivenessResult == nil)
        #expect(action.confirmedBy == nil)
    }

    @Test func nonSubstantiveUpdateKeepsEffectiveness() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try completedAction(item, in: ra, in: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)
        try CorrectiveActionEditing.update(action, in: ra, measure: "난간 설치", responsibleName: "새담당",
                                           status: .completed, implementedAt: when, postRiskLevel: .low,
                                           at: when.addingTimeInterval(10), context: ctx)
        #expect(action.effectivenessResult == .effective)
        #expect(action.responsibleName == "새담당")
    }

    @Test func updateFailedCommitRestoresFieldsAndEffectiveness() throws {
        struct CommitFailed: Error {}
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try completedAction(item, in: ra, in: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)
        #expect(throws: CommitFailed.self) {
            try CorrectiveActionEditing.update(action, in: ra, measure: "변경", status: .notStarted,
                                               at: when.addingTimeInterval(5), context: ctx,
                                               commit: { throw CommitFailed() })
        }
        #expect(action.measure == "난간 설치")
        #expect(action.status == .completed)
        #expect(action.implementedAt == when)
        #expect(action.postRiskLevel == .low)
        #expect(action.effectivenessResult == .effective)
        #expect(action.confirmedBy == "김확인")
    }

    // MARK: - confirmEffectiveness (.completed 에서만)

    @Test func effectivenessRejectedWhenNotCompleted() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간", at: when, context: ctx)
        #expect(throws: CorrectiveActionError.effectivenessPreconditionUnmet) {
            try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)
        }
    }

    @Test func effectivenessRejectedWhenNoPostRisk() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        // completed with implementedAt but NO postRiskLevel
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간", at: when, context: ctx)
        try CorrectiveActionEditing.update(action, in: ra, measure: "난간", status: .completed,
                                           implementedAt: when, postRiskLevel: nil, at: when, context: ctx)
        #expect(throws: CorrectiveActionError.effectivenessPreconditionUnmet) {
            try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인", at: when, context: ctx)
        }
    }

    @Test func effectivenessRejectsBlankConfirmer() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try completedAction(item, in: ra, in: ctx)
        #expect(throws: CorrectiveActionError.emptyConfirmer) {
            try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "   ", at: when, context: ctx)
        }
    }

    @Test func effectivenessRecordsAndPersists() throws {
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try completedAction(item, in: ra, in: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .partiallyEffective,
                                                         by: "김확인", at: when.addingTimeInterval(30), context: ctx)
        #expect(action.effectivenessResult == .partiallyEffective)
        #expect(action.confirmedBy == "김확인")
        #expect(action.effectivenessConfirmedAt == when.addingTimeInterval(30))
        #expect(action.isEffectivenessComplete)
        #expect(!action.isEffectivelyResolved)   // partial ≠ effective
    }

    /// isEffectivenessComplete requires status == .completed even if the other fields are set
    /// (a corrupted non-completed record must never read as complete).
    @Test func isEffectivenessCompleteRequiresCompletedStatus() throws {
        let ctx = try makeContext()
        let (_, item) = try startedAssessment(in: ctx)
        let action = CorrectiveAction(item: item, measure: "난간")
        action.status = .inProgress
        action.implementedAt = when
        action.postRiskLevel = .low
        action.effectivenessResult = .effective
        action.confirmedBy = "김확인"
        action.effectivenessConfirmedAt = when
        #expect(!action.isEffectivenessComplete)
        #expect(!action.isEffectivelyResolved)
    }

    @Test func confirmEffectivenessFailedCommitRestores() throws {
        struct CommitFailed: Error {}
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let action = try completedAction(item, in: ra, in: ctx)
        let priorUpdatedAt = ra.updatedAt
        #expect(throws: CommitFailed.self) {
            try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: .effective, by: "김확인",
                                                             at: when.addingTimeInterval(50), context: ctx,
                                                             commit: { throw CommitFailed() })
        }
        #expect(action.effectivenessResult == nil)
        #expect(action.confirmedBy == nil)
        #expect(action.effectivenessConfirmedAt == nil)
        #expect(ra.updatedAt == priorUpdatedAt)
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

    @Test func removeFailedCommitRestoresStoreAndMemory() throws {
        struct CommitFailed: Error {}
        let ctx = try makeContext()
        let (ra, item) = try startedAssessment(in: ctx)
        let a1 = try CorrectiveActionEditing.add(to: item, in: ra, measure: "조치1", at: when, context: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "조치2", at: when, context: ctx)
        let priorUpdatedAt = ra.updatedAt
        #expect(throws: CommitFailed.self) {
            try CorrectiveActionEditing.remove(a1, in: ra, at: when.addingTimeInterval(5),
                                               context: ctx, commit: { throw CommitFailed() })
        }
        // memory restored: both actions still present, a1 re-attached
        #expect((item.correctiveActions ?? []).count == 2)
        #expect((item.correctiveActions ?? []).contains { $0 === a1 })
        #expect(ra.updatedAt == priorUpdatedAt)
        // store restored: both persist
        let fresh = ModelContext(ctx.container)
        #expect(try fresh.fetch(FetchDescriptor<CorrectiveAction>()).count == 2)
    }
}
