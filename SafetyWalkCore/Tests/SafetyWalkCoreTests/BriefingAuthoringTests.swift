import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-TBM-1 §2.1 — 브리핑 생성은 단일 원자 연산(`AssessmentAuthoring.create` 와 같은 형태):
// Site 만 필수, Area/Program/Assessment 는 선택 UUID, 결과는 항상 .draft, 실패 시 store·메모리에
// 유령이 남지 않는다.
@Suite("BriefingAuthoring — 브리핑 생성 (TBM-1)")
struct BriefingAuthoringTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Site 만으로도 생성되고 항상 draft 로 태어난다")
    func createsMinimalDraftBriefing() throws {
        let ctx = try makeContext()
        let siteId = UUID()
        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: siteId, siteName: "1공장"), in: ctx)

        #expect(briefing.status == .draft)
        #expect(briefing.siteId == siteId)
        #expect(briefing.siteName == "1공장")
        #expect(briefing.areaId == nil)
        #expect(briefing.programId == nil)
        #expect(briefing.assessmentId == nil)
        #expect(briefing.conductedAt == nil)
        #expect(briefing.finalizedAt == nil)
        #expect(briefing.cancelledAt == nil)
        #expect(try ctx.fetch(FetchDescriptor<SafetyBriefing>()).count == 1)
    }

    @Test("Area·Program·Assessment 는 UUID 참조로만 값 스냅샷된다 — 관계가 아니다")
    func linksOptionalReferencesByUUID() throws {
        let ctx = try makeContext()
        let areaId = UUID(), programId = UUID(), assessmentId = UUID()
        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장", areaId: areaId,
                         programId: programId, assessmentId: assessmentId,
                         briefingProfile: .krTBM, taskDescription: "굴착 작업",
                         occurredAt: when, location: "A동", ownerName: "홍길동"),
            in: ctx)

        #expect(briefing.areaId == areaId)
        #expect(briefing.programId == programId)
        #expect(briefing.assessmentId == assessmentId)
        #expect(briefing.briefingProfile == .krTBM)
        #expect(briefing.taskDescription == "굴착 작업")
        #expect(briefing.location == "A동")
        #expect(briefing.ownerName == "홍길동")
    }

    @Test("현장명이 비어 있으면 거부되고 아무것도 저장되지 않는다")
    func rejectsBlankSiteName() throws {
        let ctx = try makeContext()
        #expect(throws: BriefingAuthoringError.emptySiteName) {
            try BriefingAuthoring.create(BriefingDraft(siteId: UUID(), siteName: "   "), in: ctx)
        }
        #expect(try ctx.fetch(FetchDescriptor<SafetyBriefing>()).isEmpty)
    }

    @Test("commit 이 실패하면 store·메모리 어디에도 남지 않는다")
    func failedCreateLeavesNoGhost() throws {
        let ctx = try makeContext()
        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try BriefingAuthoring.create(BriefingDraft(siteId: UUID(), siteName: "1공장"),
                                         in: ctx, commit: { throw Boom() })
        }
        #expect(try ctx.fetch(FetchDescriptor<SafetyBriefing>()).isEmpty)
    }
}
