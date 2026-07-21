import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-TBM-3 code-review — iOS/Mac 양쪽이 각자 만들던 "assessmentId로 평가 조회"를
// 하나로 합친 헬퍼. 읽기 전용.
@Suite("BriefingAssessmentLink — 값 UUID로 연결된 평가 조회 (TBM-3)")
struct BriefingAssessmentLinkTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
    }

    @Test("연결된 평가가 있으면 그 평가를 반환한다")
    func resolvesLinkedAssessment() throws {
        let ctx = try makeContext()
        let ra = try AssessmentAuthoring.create(
            AssessmentDraft(kind: .regular, method: .frequencySeverity,
                            siteId: UUID(), siteName: "1공장", assessorName: "홍길동"),
            now: Date(), in: ctx)
        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장", assessmentId: ra.id), in: ctx)

        let resolved = BriefingAssessmentLink.resolve(briefing, in: ctx)
        #expect(resolved?.id == ra.id)
    }

    @Test("standalone(연결 없음) 브리핑은 nil")
    func standaloneReturnsNil() throws {
        let ctx = try makeContext()
        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장"), in: ctx)

        #expect(BriefingAssessmentLink.resolve(briefing, in: ctx) == nil)
    }

    @Test("연결된 평가가 삭제됐으면 nil (fail-closed, 크래시 없음)")
    func deletedLinkedAssessmentReturnsNil() throws {
        let ctx = try makeContext()
        let ra = try AssessmentAuthoring.create(
            AssessmentDraft(kind: .regular, method: .frequencySeverity,
                            siteId: UUID(), siteName: "1공장", assessorName: "홍길동"),
            now: Date(), in: ctx)
        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장", assessmentId: ra.id), in: ctx)
        try AssessmentDeletion.delete(ra, in: ctx)

        #expect(BriefingAssessmentLink.resolve(briefing, in: ctx) == nil)
    }
}
