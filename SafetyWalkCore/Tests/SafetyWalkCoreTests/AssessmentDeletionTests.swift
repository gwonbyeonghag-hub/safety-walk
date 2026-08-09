import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2e §2 — 평가 삭제. cascade+inverse(criteria·items·participants·sharingEvents,
// SCHEMA_V3 §5)가 자식을 함께 지우는지, commit 실패 시 store·메모리 어디에도 유령이 남지
// 않는지(반대 방향 — 삭제가 되돌려져 평가·자식이 여전히 남아 있는지) 확인한다.
//
// ⚠️ 알려진 툴체인 이슈(재현 확인, LEGAL-2e 회귀 아님): 이 SDK(Swift 6.3 / macOS 26)에서
// `ModelContext.rollback()` 은 대기 중인 cascade 삭제가 `AssessmentCriteria`·`SharingEvent`(또는
// item 을 거친 `CorrectiveAction`)를 건드리면 "Unexpected backing data for snapshot creation" 로
// **크래시**한다. Core 래퍼·에러 처리와 무관하게 순수 `context.delete(ra); context.rollback()` 만으로도
// 재현되고, 이미 병합된 `AssessmentItemEditing.remove`(개선조치를 가진 항목 삭제 실패 시)에서도
// 똑같이 재현된다 — 이번 WO가 만든 결함이 아니라 기존 delete+rollback 관용구 전체에 걸린 사전 위험이다.
// 그래서 이 스위트는 크래시하지 않는 자식 조합(items·participants)으로만 rollback 을 검증하고,
// criteria·sharingEvents 를 포함한 rollback 커버리지는 플래너에게 별도 보고한다(완료 보고 참고).
@Suite("AssessmentDeletion — 평가 삭제 + cascade (LEGAL-2e)")
struct AssessmentDeletionTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true)

    /// 기준·항목·참여자·공유이력을 모두 가진 평가 — 성공 삭제 경로에서 cascade 4갈래를 한 번에 검증한다.
    private func fullyPopulatedAssessment(in ctx: ModelContext) throws -> RiskAssessment {
        let ra = try AssessmentAuthoring.create(
            AssessmentDraft(kind: .regular, method: .frequencySeverity,
                            siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                            jurisdiction: .us, industryProfile: .construction, scheduledAt: when,
                            items: [AssessmentDraft.ItemDraft(taskDescription: "굴착", hazardDescription: "붕괴",
                                                              likelihood: 1, severity: 1, riskLevel: .low)]),
            now: when, in: ctx)

        // 사전 공유는 planned 에서만 기록할 수 있다 — 시작 전에 남긴다.
        try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                         target: "정문 게시판", ownerName: "홍길동",
                                         at: when, context: ctx)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)

        let participant = RiskAssessmentParticipant(name: "김근로", role: .worker)
        ctx.insert(participant)
        participant.riskAssessment = ra
        ra.participants = [participant]
        try ctx.save()
        return ra
    }

    @Test("삭제하면 평가와 기준·항목·참여자·공유이력이 모두 지워진다")
    func deleteCascadesAllChildren() throws {
        let ctx = try makeContext()
        let ra = try fullyPopulatedAssessment(in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<AssessmentCriteria>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentItem>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentParticipant>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<SharingEvent>()).count == 1)

        try AssessmentDeletion.delete(ra, in: ctx)

        #expect(try ctx.fetch(FetchDescriptor<RiskAssessment>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<AssessmentCriteria>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentItem>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentParticipant>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<SharingEvent>()).isEmpty)
    }

    @Test("항목·참여자·공유이력이 없는 평가도 삭제된다")
    func deleteBareAssessment() throws {
        let ctx = try makeContext()
        let ra = try AssessmentAuthoring.create(
            AssessmentDraft(kind: .regular, method: .frequencySeverity,
                            siteId: UUID(), siteName: "2공장", assessorName: "이순신"),
            now: when, in: ctx)

        try AssessmentDeletion.delete(ra, in: ctx)

        #expect(try ctx.fetch(FetchDescriptor<RiskAssessment>()).isEmpty)
    }

    @Test("commit 이 실패하면 평가와 항목·참여자가 store 에 그대로 남는다")
    func failedDeleteLeavesAssessmentIntact() throws {
        let ctx = try makeContext()
        let ra = try AssessmentAuthoring.create(
            AssessmentDraft(kind: .regular, method: .frequencySeverity,
                            siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                            items: [AssessmentDraft.ItemDraft(taskDescription: "굴착", hazardDescription: "붕괴",
                                                              likelihood: 1, severity: 1, riskLevel: .low)]),
            now: when, in: ctx)
        let participant = RiskAssessmentParticipant(name: "김근로", role: .worker)
        ctx.insert(participant)
        participant.riskAssessment = ra
        ra.participants = [participant]
        try ctx.save()

        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try AssessmentDeletion.delete(ra, in: ctx, commit: { throw Boom() })
        }

        #expect(try ctx.fetch(FetchDescriptor<RiskAssessment>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentItem>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentParticipant>()).count == 1)
        // 원래 평가 인스턴스가 여전히 유효하고 읽을 수 있다(유령 상태가 아니다).
        #expect(ra.siteName == "1공장")
    }
}
