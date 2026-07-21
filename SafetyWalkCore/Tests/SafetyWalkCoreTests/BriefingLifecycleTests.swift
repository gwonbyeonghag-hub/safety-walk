import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-TBM-1 §2.2 — 브리핑 수명주기: conduct(draft→conducted, 위험 스냅샷 값복사) /
// finalize(conducted→finalized) / cancel(draft·conducted→cancelled). 각 전환은 단일 원자
// 연산이고, 잠금 시점(conducted=내용·스냅샷, finalized=참석·서명)을 강제한다.
@Suite("BriefingLifecycle — conduct/finalize/cancel (TBM-1)")
struct BriefingLifecycleTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true)

    private func draftBriefing(in ctx: ModelContext, assessmentId: UUID? = nil) throws -> SafetyBriefing {
        try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장", assessmentId: assessmentId), in: ctx)
    }

    /// 항목 1개(개선조치 1건 포함)를 가진 진행중 평가 — conduct 의 값 스냅샷 복사를 검증한다.
    private func inProgressAssessment(in ctx: ModelContext) throws -> RiskAssessment {
        let ra = try AssessmentAuthoring.create(
            AssessmentDraft(kind: .regular, method: .frequencySeverity,
                            siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                            items: [AssessmentDraft.ItemDraft(taskDescription: "굴착", hazardDescription: "붕괴",
                                                              currentControls: "표지판 설치",
                                                              likelihood: 3, severity: 3, riskLevel: .high,
                                                              measure: "안전난간 설치", responsibleName: "김담당")]),
            now: when, in: ctx)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        return ra
    }

    // MARK: - conduct

    @Test("standalone 브리핑(연결 평가 없음)은 위험 스냅샷 없이 진행된다")
    func conductStandaloneHasNoSnapshots() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)

        try BriefingLifecycle.conduct(briefing, briefingContent: "오늘의 작업 안전 유의사항", now: when, in: ctx)

        #expect(briefing.status == .conducted)
        #expect(briefing.conductedAt == when)
        #expect(briefing.briefingContent == "오늘의 작업 안전 유의사항")
        #expect(briefing.riskSnapshots?.isEmpty == true)
    }

    @Test("연결 평가가 있으면 항목·개선조치가 값 스냅샷으로 복사된다")
    func conductCopiesLinkedAssessmentItemsAsSnapshots() throws {
        let ctx = try makeContext()
        let ra = try inProgressAssessment(in: ctx)
        let briefing = try draftBriefing(in: ctx, assessmentId: ra.id)

        try BriefingLifecycle.conduct(briefing, briefingContent: "굴착 붕괴 위험 전달",
                                      sourceAssessment: ra, now: when, in: ctx)

        let snapshots = try #require(briefing.riskSnapshots)
        #expect(snapshots.count == 1)
        let snap = try #require(snapshots.first)
        #expect(snap.sourceAssessmentId == ra.id)
        #expect(snap.sourceItemId == ra.items?.first?.id)
        #expect(snap.taskDescription == "굴착")
        #expect(snap.hazardDescription == "붕괴")
        #expect(snap.currentControls == "표지판 설치")
        #expect(snap.riskLevel == .high)
        #expect(snap.likelihood == 3)
        #expect(snap.severity == 3)

        let decoded = try BriefingControlMeasuresSnapshot.decode(
            snap.controlMeasuresSnapshot, formatVersion: snap.controlMeasuresFormatVersion)
        #expect(decoded.measures.count == 1)
        #expect(decoded.measures.first?.measure == "안전난간 설치")
        #expect(decoded.measures.first?.responsibleName == "김담당")

        // 원본 평가 수정과 무관하게 스냅샷은 불변 — 원본을 나중에 바꿔도 스냅샷은 그대로다.
        let item = try #require(ra.items?.first)
        let action = try #require(item.correctiveActions?.first)
        try CorrectiveActionEditing.update(action, in: ra, measure: "바뀐 대책", status: .notStarted,
                                           at: when, context: ctx)
        let stillDecoded = try BriefingControlMeasuresSnapshot.decode(
            snap.controlMeasuresSnapshot, formatVersion: snap.controlMeasuresFormatVersion)
        #expect(stillDecoded.measures.first?.measure == "안전난간 설치")
    }

    @Test("draft 가 아니면 진행할 수 없다")
    func conductRejectsNonDraft() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "1차", now: when, in: ctx)

        #expect(throws: BriefingLifecycleError.notDraft) {
            try BriefingLifecycle.conduct(briefing, briefingContent: "2차", now: when.addingTimeInterval(60), in: ctx)
        }
        #expect(briefing.briefingContent == "1차")
    }

    @Test("전달내용이 비어 있으면 거부된다")
    func conductRejectsBlankContent() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        #expect(throws: BriefingLifecycleError.emptyBriefingContent) {
            try BriefingLifecycle.conduct(briefing, briefingContent: "   ", now: when, in: ctx)
        }
        #expect(briefing.status == .draft)
    }

    @Test("연결된 평가인데 sourceAssessment 를 안 주면 거부된다")
    func conductRequiresSourceAssessmentWhenLinked() throws {
        let ctx = try makeContext()
        let ra = try inProgressAssessment(in: ctx)
        let briefing = try draftBriefing(in: ctx, assessmentId: ra.id)
        #expect(throws: BriefingLifecycleError.sourceAssessmentRequired) {
            try BriefingLifecycle.conduct(briefing, briefingContent: "전달", now: when, in: ctx)
        }
    }

    @Test("sourceAssessment 가 briefing.assessmentId 와 다르면 거부된다")
    func conductRejectsMismatchedSourceAssessment() throws {
        let ctx = try makeContext()
        let ra = try inProgressAssessment(in: ctx)
        let other = try inProgressAssessment(in: ctx)
        let briefing = try draftBriefing(in: ctx, assessmentId: ra.id)
        #expect(throws: BriefingLifecycleError.sourceAssessmentMismatch) {
            try BriefingLifecycle.conduct(briefing, briefingContent: "전달", sourceAssessment: other, now: when, in: ctx)
        }
    }

    @Test("연결 평가가 없는데 sourceAssessment 를 주면 거부된다")
    func conductRejectsUnexpectedSourceAssessment() throws {
        let ctx = try makeContext()
        let ra = try inProgressAssessment(in: ctx)
        let briefing = try draftBriefing(in: ctx)   // assessmentId 없음(standalone)
        #expect(throws: BriefingLifecycleError.sourceAssessmentMismatch) {
            try BriefingLifecycle.conduct(briefing, briefingContent: "전달", sourceAssessment: ra, now: when, in: ctx)
        }
    }

    @Test("commit 이 실패하면 draft 로 남고 스냅샷도 남지 않는다")
    func failedConductLeavesNoGhost() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try BriefingLifecycle.conduct(briefing, briefingContent: "전달", sourceAssessment: nil,
                                          now: when, in: ctx, commit: { throw Boom() })
        }
        #expect(briefing.status == .draft)
        #expect(briefing.briefingContent.isEmpty)
        #expect(briefing.conductedAt == nil)
        #expect(try ctx.fetch(FetchDescriptor<BriefingRiskItemSnapshot>()).isEmpty)
    }

    // MARK: - finalize

    @Test("conducted 는 finalize 로 전환된다")
    func finalizeTransitionsConducted() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "전달", now: when, in: ctx)

        try BriefingLifecycle.finalize(briefing, now: when.addingTimeInterval(600), in: ctx)

        #expect(briefing.status == .finalized)
        #expect(briefing.finalizedAt == when.addingTimeInterval(600))
    }

    @Test("draft 는 finalize 할 수 없다")
    func finalizeRejectsDraft() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        #expect(throws: BriefingLifecycleError.notConducted) {
            try BriefingLifecycle.finalize(briefing, now: when, in: ctx)
        }
    }

    @Test("commit 이 실패하면 conducted 로 남는다")
    func failedFinalizeRestoresConducted() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "전달", now: when, in: ctx)
        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try BriefingLifecycle.finalize(briefing, now: when.addingTimeInterval(600), in: ctx, commit: { throw Boom() })
        }
        #expect(briefing.status == .conducted)
        #expect(briefing.finalizedAt == nil)
    }

    // MARK: - cancel

    @Test("draft 는 취소된다")
    func cancelFromDraft() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        try BriefingLifecycle.cancel(briefing, reason: "현장 작업 취소", now: when, in: ctx)
        #expect(briefing.status == .cancelled)
        #expect(briefing.cancelledAt == when)
        #expect(briefing.cancellationReason == "현장 작업 취소")
    }

    @Test("conducted 도 취소된다")
    func cancelFromConducted() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "전달", now: when, in: ctx)
        try BriefingLifecycle.cancel(briefing, reason: "우천 취소", now: when.addingTimeInterval(60), in: ctx)
        #expect(briefing.status == .cancelled)
    }

    @Test("finalized 는 취소할 수 없다 — 정정 경로가 맞다")
    func cancelRejectsFinalized() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "전달", now: when, in: ctx)
        try BriefingLifecycle.finalize(briefing, now: when.addingTimeInterval(60), in: ctx)
        #expect(throws: BriefingLifecycleError.notCancellable) {
            try BriefingLifecycle.cancel(briefing, reason: "사유", now: when.addingTimeInterval(120), in: ctx)
        }
    }

    @Test("취소 사유가 비어 있으면 거부된다")
    func cancelRejectsBlankReason() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        #expect(throws: BriefingLifecycleError.emptyCancellationReason) {
            try BriefingLifecycle.cancel(briefing, reason: "  ", now: when, in: ctx)
        }
        #expect(briefing.status == .draft)
    }
}
