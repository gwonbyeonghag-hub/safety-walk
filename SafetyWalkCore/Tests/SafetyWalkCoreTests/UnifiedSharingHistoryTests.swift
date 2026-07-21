import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-TBM-3 §2 — 통합 공유 이력: 한 평가의 확정된 SafetyBriefing(TBM) + SharingEvent(비TBM)를
// 하나의 시간순 이력으로 합친다. 읽기 전용 — 어떤 것도 insert/delete/save 하지 않는다.
@Suite("UnifiedSharingHistory — TBM+비TBM 통합 이력 (TBM-3)")
struct UnifiedSharingHistoryTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)

    /// 사전 공유(.pre)는 planned + scheduledAt 필수(SharingEventPolicy) — 항상 일정을 채워 만든다.
    private func plannedAssessment(in ctx: ModelContext) throws -> RiskAssessment {
        try AssessmentAuthoring.create(
            AssessmentDraft(kind: .regular, method: .frequencySeverity,
                            siteId: UUID(), siteName: "1공장", assessorName: "홍길동", scheduledAt: when),
            now: when, in: ctx)
    }

    /// draft → conducted → finalized 까지 진행한 브리핑 — assessmentId 로 값 연결.
    @discardableResult
    private func finalizedBriefing(linkedTo assessment: RiskAssessment?, in ctx: ModelContext,
                                   at date: Date) throws -> SafetyBriefing {
        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장", assessmentId: assessment?.id), in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "전달", sourceAssessment: assessment,
                                      now: date, in: ctx)
        try BriefingLifecycle.finalize(briefing, now: date, in: ctx)
        return briefing
    }

    @Test("연결·기록이 없으면 빈 이력")
    func emptyWhenNothingLinked() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        #expect(UnifiedSharingHistory.entries(for: ra, in: ctx).isEmpty)
    }

    @Test("SharingEvent 만 있으면 그 순서 그대로 반영된다")
    func sharingEventsOnly() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                         target: "정문 게시판", ownerName: "홍길동", at: when, context: ctx)

        let entries = UnifiedSharingHistory.entries(for: ra, in: ctx)
        #expect(entries.count == 1)
        if case .sharingEvent(let e) = entries[0] {
            #expect(e.target == "정문 게시판")
        } else {
            Issue.record("expected a .sharingEvent entry")
        }
    }

    @Test("finalized 브리핑만 있으면 하나의 .briefing 항목으로 반환된다")
    func finalizedBriefingOnly() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        try finalizedBriefing(linkedTo: ra, in: ctx, at: when)

        let entries = UnifiedSharingHistory.entries(for: ra, in: ctx)
        #expect(entries.count == 1)
        guard case .briefing(let b) = entries[0] else {
            Issue.record("expected a .briefing entry"); return
        }
        #expect(b.status == .finalized)
        #expect(b.assessmentId == ra.id)
    }

    @Test("draft·conducted·cancelled 브리핑은 통합 이력에서 제외된다 — finalized 만 TBM 공유 증명")
    func nonFinalizedBriefingsExcluded() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)

        // draft
        _ = try BriefingAuthoring.create(BriefingDraft(siteId: UUID(), siteName: "1공장", assessmentId: ra.id), in: ctx)
        // conducted (not finalized)
        let conducted = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장", assessmentId: ra.id), in: ctx)
        try BriefingLifecycle.conduct(conducted, briefingContent: "전달", sourceAssessment: ra, now: when, in: ctx)
        // cancelled
        let cancelled = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장", assessmentId: ra.id), in: ctx)
        try BriefingLifecycle.cancel(cancelled, reason: "취소", now: when, in: ctx)

        #expect(UnifiedSharingHistory.entries(for: ra, in: ctx).isEmpty)
    }

    @Test("다른 평가에 연결된 브리핑은 포함되지 않는다")
    func briefingLinkedToOtherAssessmentExcluded() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        let other = try plannedAssessment(in: ctx)
        try finalizedBriefing(linkedTo: other, in: ctx, at: when)

        #expect(UnifiedSharingHistory.entries(for: ra, in: ctx).isEmpty)
    }

    @Test("standalone(연결 평가 없음) 브리핑은 어떤 평가의 이력에도 나오지 않는다")
    func standaloneBriefingNeverAppears() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        try finalizedBriefing(linkedTo: nil, in: ctx, at: when)

        #expect(UnifiedSharingHistory.entries(for: ra, in: ctx).isEmpty)
    }

    @Test("TBM·비TBM 이 섞이면 시간 역순(최근 먼저)으로 합쳐진다")
    func mixedSourcesSortByDateDescending() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)

        let earliest = when
        let middle = when.addingTimeInterval(3600)
        let latest = when.addingTimeInterval(7200)

        try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                         target: "정문 게시판", ownerName: "홍길동", at: earliest, context: ctx)
        try finalizedBriefing(linkedTo: ra, in: ctx, at: latest)
        // 두 번째 SharingEvent — 사전 공유는 planned 상태에서만 가능하므로 같은 phase 로 하나 더.
        try SharingEventRecording.record(phase: .pre, method: .written, in: ra,
                                         target: "게시판2", ownerName: "홍길동", at: middle, context: ctx)

        let entries = UnifiedSharingHistory.entries(for: ra, in: ctx)
        #expect(entries.map(\.date) == [latest, middle, earliest])
        guard case .briefing = entries[0] else { Issue.record("first entry should be the finalized briefing"); return }
    }

    @Test("읽기 전용 — 조회 전후로 store 에 어떤 변화도 없다")
    func readOnlyNoMutation() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        try finalizedBriefing(linkedTo: ra, in: ctx, at: when)
        try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                         target: "정문 게시판", ownerName: "홍길동", at: when, context: ctx)

        let briefingCountBefore = try ctx.fetch(FetchDescriptor<SafetyBriefing>()).count
        let eventCountBefore = try ctx.fetch(FetchDescriptor<SharingEvent>()).count

        _ = UnifiedSharingHistory.entries(for: ra, in: ctx)
        _ = UnifiedSharingHistory.entries(for: ra, in: ctx)   // twice — idempotent, no side effect

        #expect(try ctx.fetch(FetchDescriptor<SafetyBriefing>()).count == briefingCountBefore)
        #expect(try ctx.fetch(FetchDescriptor<SharingEvent>()).count == eventCountBefore)
    }
}
