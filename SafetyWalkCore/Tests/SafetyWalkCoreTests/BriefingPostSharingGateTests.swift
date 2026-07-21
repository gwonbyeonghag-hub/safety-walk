import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-TBM-4 §2.1 — 확정 TBM 브리핑이 KR 사후 공유 게이트를 충족시킨다(LEGAL_2_ARCH §3 "조회
// 모듈이 통합"). SharingEventPolicy.isCurrent(_:SafetyBriefing:in:) 는 isCurrent(_:SharingEvent:phase:in:)
// 와 대칭인 완전성+최신성 단일 판정이고, AssessmentClosure.isClosed/openReason 이 그 결과를 소비한다.

@Suite("SharingEventPolicy/AssessmentClosure — TBM 브리핑 사후공유 게이트 (LEGAL-TBM-4)")
struct BriefingPostSharingGateTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true) // threshold 2

    /// planned(KR 이면 사전공유 포함) → inProgress → 항목 1건(기준 이내, 조치 불필요) → finalized.
    private func readyFinalizedAssessment(in ctx: ModelContext, jurisdiction: JurisdictionCode?) throws -> RiskAssessment {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                                jurisdictionSnapshot: jurisdiction, scheduledAt: when)
        ctx.insert(ra)
        try ctx.save()
        if jurisdiction == .kr {
            try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                             target: "전 근로자", ownerName: "홍길동", at: when, context: ctx)
        }
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        let item = RiskAssessmentItem(taskDescription: "운반", hazardDescription: "협착",
                                      likelihood: 1, severity: 1, riskLevel: .low)
        item.riskAssessment = ra
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        ctx.insert(item)
        ra.items = [item]
        try ctx.save()
        try AssessmentFinalization.finalize(ra, now: when, in: ctx)
        return ra
    }

    /// 연결된 평가를 conduct+finalize 까지 진행한 확정 브리핑.
    @discardableResult
    private func finalizedBriefing(for ra: RiskAssessment, in ctx: ModelContext) throws -> SafetyBriefing {
        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: ra.siteId ?? UUID(), siteName: ra.siteName, assessmentId: ra.id), in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "오늘 작업 전달", sourceAssessment: ra, now: when, in: ctx)
        try BriefingLifecycle.finalize(briefing, now: when, in: ctx)
        return briefing
    }

    @Test("KR: 확정 TBM 브리핑만으로(SharingEvent 없이) 사후 공유 게이트를 충족하고 종결된다")
    func krFinalizedBriefingSatisfiesGateWithoutSharingEvent() throws {
        let ctx = try makeContext()
        let ra = try readyFinalizedAssessment(in: ctx, jurisdiction: .kr)
        #expect(SharingEventPolicy.currentEvent(phase: .post, in: ra) == nil)
        #expect(!AssessmentClosure.isClosed(ra, in: ctx))
        #expect(AssessmentClosure.openReason(ra, in: ctx) == .postSharingMissing)

        let briefing = try finalizedBriefing(for: ra, in: ctx)
        #expect(SharingEventPolicy.isCurrent(briefing, in: ra))
        #expect(SharingEventPolicy.currentBriefing(for: ra, in: ctx)?.id == briefing.id)
        #expect(AssessmentClosure.isClosed(ra, in: ctx))
        #expect(AssessmentClosure.openReason(ra, in: ctx) == nil)
    }

    @Test("KR: 브리핑 확정 후 개선조치가 추가되면 그 브리핑은 stale 이 되어 다시 미종결")
    func staleBriefingAfterCorrectiveActionReopens() throws {
        let ctx = try makeContext()
        let ra = try readyFinalizedAssessment(in: ctx, jurisdiction: .kr)
        let briefing = try finalizedBriefing(for: ra, in: ctx)
        #expect(AssessmentClosure.isClosed(ra, in: ctx))

        let item = try #require(ra.items?.first)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "사후 추가 대책",
                                        at: when.addingTimeInterval(60), context: ctx)

        #expect(!SharingEventPolicy.isCurrent(briefing, in: ra))
        #expect(!AssessmentClosure.isClosed(ra, in: ctx))
        #expect(AssessmentClosure.openReason(ra, in: ctx) == .postSharingMissing)
    }

    @Test("US 관할에는 브리핑 게이트도 강제하지 않는다 — 기준 초과 0건이면 브리핑 없이도 종결")
    func usIgnoresBriefingGate() throws {
        let ctx = try makeContext()
        let ra = try readyFinalizedAssessment(in: ctx, jurisdiction: .us)
        #expect(AssessmentClosure.isClosed(ra, in: ctx))
    }

    @Test("관할 미설정에도 브리핑 게이트를 강제하지 않는다")
    func unsetJurisdictionIgnoresBriefingGate() throws {
        let ctx = try makeContext()
        let ra = try readyFinalizedAssessment(in: ctx, jurisdiction: nil)
        #expect(AssessmentClosure.isClosed(ra, in: ctx))
    }

    @Test("KR: 브리핑이 stale 이어도 현재 SharingEvent 가 있으면 여전히 게이트를 충족한다(공존)")
    func briefingAndSharingEventCoexist() throws {
        let ctx = try makeContext()
        let ra = try readyFinalizedAssessment(in: ctx, jurisdiction: .kr)
        let briefing = try finalizedBriefing(for: ra, in: ctx)
        #expect(AssessmentClosure.isClosed(ra, in: ctx))

        // 조치 추가로 브리핑은 stale 이 되지만, 그 뒤 기록한 사후 SharingEvent 는 현재 상태와 일치한다.
        let item = try #require(ra.items?.first)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "추가 대책",
                                        at: when.addingTimeInterval(60), context: ctx)
        #expect(!SharingEventPolicy.isCurrent(briefing, in: ra))

        try SharingEventRecording.record(phase: .post, method: .written, in: ra,
                                         target: "전 근로자", ownerName: "홍길동",
                                         at: when.addingTimeInterval(120), context: ctx)
        #expect(AssessmentClosure.isClosed(ra, in: ctx))
    }

    @Test("standalone(평가 미연결) 브리핑은 어떤 평가의 게이트도 충족하지 않는다")
    func standaloneBriefingNeverSatisfiesAnyAssessment() throws {
        let ctx = try makeContext()
        let ra = try readyFinalizedAssessment(in: ctx, jurisdiction: .kr)
        let standalone = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "다른 현장"), in: ctx)
        try BriefingLifecycle.conduct(standalone, briefingContent: "독립 TBM", sourceAssessment: nil, now: when, in: ctx)
        try BriefingLifecycle.finalize(standalone, now: when, in: ctx)

        #expect(!SharingEventPolicy.isCurrent(standalone, in: ra))
        #expect(!AssessmentClosure.isClosed(ra, in: ctx))
    }

    @Test("conducted(확정 전) 브리핑은 게이트를 충족하지 않는다")
    func conductedButNotFinalizedBriefingDoesNotSatisfyGate() throws {
        let ctx = try makeContext()
        let ra = try readyFinalizedAssessment(in: ctx, jurisdiction: .kr)
        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: ra.siteId ?? UUID(), siteName: ra.siteName, assessmentId: ra.id), in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "오늘 작업 전달", sourceAssessment: ra, now: when, in: ctx)

        #expect(!SharingEventPolicy.isCurrent(briefing, in: ra))
        #expect(!AssessmentClosure.isClosed(ra, in: ctx))
    }
}
