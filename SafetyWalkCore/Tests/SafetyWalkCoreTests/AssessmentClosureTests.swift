import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2c (반송 2차) — 종결(closed) 파생 + 필수 계획. closed 는 파생: finalized AND 잠긴 기준을
// decode해 모든 항목이 CURRENT한 결정을 갖고(스냅샷 누락·손상·불완전·stale이면 fail-closed), 모든 기준
// 초과 항목이 ≥1 개선조치 + 각 조치가 효과 있음(effective)으로 효과확인 완료. 부분·없음·미완료 → 미종결.

@Suite("AssessmentClosure — closed 파생 (fail-closed) + 필수 계획 (LEGAL-2c 2차)")
struct AssessmentClosureTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true) // threshold 2

    private func startedAssessment(in ctx: ModelContext) throws -> RiskAssessment {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "현장", status: .planned)
        ctx.insert(ra)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        ra.items = []
        try ctx.save()
        return ra
    }

    /// (2,2)→4→medium = 기준 초과; (1,1)→1→low = 기준 이내. Confirmed under the locked criteria.
    @discardableResult
    private func addItem(_ ra: RiskAssessment, likelihood: Int, severity: Int, level: RiskLevel,
                         in ctx: ModelContext) throws -> RiskAssessmentItem {
        let item = RiskAssessmentItem(likelihood: likelihood, severity: severity, riskLevel: level)
        item.riskAssessment = ra
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        ctx.insert(item)
        ra.items = (ra.items ?? []) + [item]
        try ctx.save()
        return item
    }

    /// Plan → completed(이행일·개선후위험도) → 효과확인 with `result`.
    private func addEffectiveAction(_ item: RiskAssessmentItem, in ra: RiskAssessment,
                                    result: EffectivenessResult, in ctx: ModelContext) throws {
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)
        try CorrectiveActionEditing.update(action, in: ra, measure: "난간 설치", status: .completed,
                                           implementedAt: when, postRiskLevel: .low, at: when, context: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(action, in: ra, result: result, by: "김확인", at: when, context: ctx)
    }

    // MARK: - 필수 계획 predicate

    @Test func exceedsItemWithoutActionHasNoPlan() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        #expect(item.criteriaDecision == .exceedsThreshold)
        #expect(!item.hasRequiredCorrectiveActionPlan)
    }

    @Test func exceedsItemWithMeasureActionHasPlan() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)
        #expect(item.hasRequiredCorrectiveActionPlan)
    }

    @Test func withinItemNeedsNoPlan() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 1, severity: 1, level: .low, in: ctx)
        #expect(item.criteriaDecision == .withinThreshold)
        #expect(item.hasRequiredCorrectiveActionPlan)
    }

    // MARK: - closed 파생 (핵심)

    @Test func notFinalizedIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        try addItem(ra, likelihood: 1, severity: 1, level: .low, in: ctx)
        #expect(ra.status == .inProgress)
        #expect(!AssessmentClosure.isClosed(ra))
    }

    @Test func finalizedWithNoExceedsItemsIsClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        try addItem(ra, likelihood: 1, severity: 1, level: .low, in: ctx)   // 기준 이내만
        ra.status = .finalized
        #expect(AssessmentClosure.isClosed(ra))
    }

    @Test func finalizedExceedsAllEffectiveIsClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try addEffectiveAction(item, in: ra, result: .effective, in: ctx)
        ra.status = .finalized
        #expect(AssessmentClosure.isClosed(ra))
    }

    @Test func partiallyEffectiveIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try addEffectiveAction(item, in: ra, result: .partiallyEffective, in: ctx)
        ra.status = .finalized
        #expect(!AssessmentClosure.isClosed(ra))
    }

    @Test func ineffectiveIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try addEffectiveAction(item, in: ra, result: .ineffective, in: ctx)
        ra.status = .finalized
        #expect(!AssessmentClosure.isClosed(ra))
    }

    @Test func exceedsWithZeroActionsIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        ra.status = .finalized
        #expect(!AssessmentClosure.isClosed(ra))
    }

    @Test func exceedsWithUnconfirmedActionIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)  // .notStarted
        ra.status = .finalized
        #expect(!AssessmentClosure.isClosed(ra))
    }

    /// A completed-only effectiveness record that has been corrupted to a non-completed status must
    /// never count as resolved (손상된 효과확인 필드 → 미종결).
    @Test func notCompletedCorruptEffectivenessIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)
        action.status = .inProgress
        action.implementedAt = when
        action.postRiskLevel = .low
        action.effectivenessResult = .effective
        action.confirmedBy = "김확인"
        action.effectivenessConfirmedAt = when
        ra.status = .finalized
        #expect(!AssessmentClosure.isClosed(ra))
    }

    // MARK: - fail-closed (현재 결정 검증)

    @Test func missingCriteriaIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try addEffectiveAction(item, in: ra, result: .effective, in: ctx)
        ra.status = .finalized
        ra.criteria = nil
        #expect(!AssessmentClosure.isClosed(ra))
    }

    @Test func corruptCriteriaIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try addEffectiveAction(item, in: ra, result: .effective, in: ctx)
        ra.status = .finalized
        ra.criteria?.matrixData = Data("garbage".utf8)   // fail-closed decode
        #expect(!AssessmentClosure.isClosed(ra))
    }

    @Test func incompleteConfirmationIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try addEffectiveAction(item, in: ra, result: .effective, in: ctx)
        ra.status = .finalized
        item.decisionConfirmedBy = nil   // incomplete confirmation
        #expect(!AssessmentClosure.isClosed(ra))
    }

    @Test func staleDecisionIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try addEffectiveAction(item, in: ra, result: .effective, in: ctx)
        ra.status = .finalized
        // Risk input drops to within (1×1=1) but the stored decision is still exceeds → stale.
        item.likelihood = 1
        item.severity = 1
        item.riskLevel = .low
        #expect(!AssessmentClosure.isClosed(ra))
    }
}
