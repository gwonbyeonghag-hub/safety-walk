import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2c — 종결(closed) 파생 + 필수 개선조치 계획 규칙 (LEGAL_2_ARCH §1.1). closed 는 저장 상태가
// 아니라 파생: finalized AND 모든 기준 초과 항목이 ≥1 개선조치 + 각 조치가 이행·효과확인(effective) 완료.
// 부분 효과·효과 없음 → 미종결. 기준 초과 0건이면 finalized 즉시 종결. (2c는 finalize 전환을 소유하지 않으므로
// 테스트는 파생만 검증하고 status는 직접 설정한다.)

@Suite("AssessmentClosure — closed 파생 + 필수 계획 (LEGAL-2c)")
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

    /// Adds a confirmed item: (2,2)→4→medium is 기준 초과; (1,1)→1→low is 기준 이내.
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

    private func addEffectiveAction(_ item: RiskAssessmentItem, in ra: RiskAssessment,
                                    result: EffectivenessResult, in ctx: ModelContext) throws {
        let action = try CorrectiveActionEditing.add(
            to: item, in: ra, measure: "난간 설치", implementedAt: when, postRiskLevel: .low, at: when, context: ctx)
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
        #expect(item.hasRequiredCorrectiveActionPlan)   // 초과 아님 → 계획 불필요
    }

    // MARK: - closed 파생

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
        #expect(AssessmentClosure.isClosed(ra))   // 기준 초과 0건 → 즉시 종결
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
        #expect(!AssessmentClosure.isClosed(ra))   // 부분 효과 → 미종결
    }

    @Test func ineffectiveIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try addEffectiveAction(item, in: ra, result: .ineffective, in: ctx)
        ra.status = .finalized
        #expect(!AssessmentClosure.isClosed(ra))   // 효과 없음 → 미종결
    }

    @Test func exceedsWithZeroActionsIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)   // 초과인데 조치 없음
        ra.status = .finalized
        #expect(!AssessmentClosure.isClosed(ra))
    }

    @Test func exceedsWithUnconfirmedActionIsNotClosed() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium, in: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치",
                                        implementedAt: when, postRiskLevel: .low, at: when, context: ctx)
        ra.status = .finalized
        #expect(!AssessmentClosure.isClosed(ra))   // 효과확인 미완료 → 미종결
    }
}
