import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-TBM-1 §2.6 — 삭제 보호 확인(코드 없음, 확인·테스트만). `SafetyBriefing.siteId`/
// `programId`/`assessmentId` 는 UUID+값 스냅샷일 뿐 SwiftData 관계가 아니므로(SCHEMA_V3 §5),
// Site/Program/Assessment 를 지워도 과거 브리핑은 cascade 삭제되지 않는다 — 구조적으로 cascade
// 경로가 없다는 것을 실제 삭제로 증명한다.
@Suite("SafetyBriefing 삭제 보호 — Site/Program/Assessment 삭제는 브리핑을 지우지 않는다 (TBM-1)")
struct BriefingDeletionProtectionTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Site 삭제는 참조하는 브리핑을 지우지 않는다")
    func siteDeletionSurvivesBriefing() throws {
        let ctx = try makeContext()
        let site = Site(name: "1공장")
        ctx.insert(site)
        try ctx.save()

        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: site.id, siteName: site.name), in: ctx)
        let briefingId = briefing.id

        ctx.delete(site)
        try ctx.save()

        let survivors = try ctx.fetch(FetchDescriptor<SafetyBriefing>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.id == briefingId)
        #expect(survivors.first?.siteId == site.id)   // 값 스냅샷 그대로 — nullify 되지 않는다
    }

    @Test("Program 삭제는 참조하는 브리핑을 지우지 않는다")
    func programDeletionSurvivesBriefing() throws {
        let ctx = try makeContext()
        let program = RiskAssessmentProgram(siteId: UUID(), siteName: "1공장", jurisdiction: .kr)
        ctx.insert(program)
        try ctx.save()

        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장", programId: program.id), in: ctx)
        let briefingId = briefing.id

        ctx.delete(program)
        try ctx.save()

        let survivors = try ctx.fetch(FetchDescriptor<SafetyBriefing>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.id == briefingId)
        #expect(survivors.first?.programId == program.id)
    }

    @Test("Assessment 삭제는 참조하는 브리핑을 지우지 않는다 — conduct 후 스냅샷도 살아남는다")
    func assessmentDeletionSurvivesConductedBriefingSnapshots() throws {
        let ctx = try makeContext()
        let ra = try AssessmentAuthoring.create(
            AssessmentDraft(kind: .regular, method: .frequencySeverity,
                            siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                            items: [AssessmentDraft.ItemDraft(taskDescription: "굴착", hazardDescription: "붕괴",
                                                              likelihood: 1, severity: 1, riskLevel: .low)]),
            now: when, in: ctx)

        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장", assessmentId: ra.id), in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "굴착 위험 전달",
                                      sourceAssessment: ra, now: when, in: ctx)
        let briefingId = briefing.id

        try AssessmentDeletion.delete(ra, in: ctx)

        let survivors = try ctx.fetch(FetchDescriptor<SafetyBriefing>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.id == briefingId)
        #expect(survivors.first?.assessmentId == ra.id)   // 값 스냅샷 — 지워진 평가의 id 를 그대로 보존
        // riskSnapshots 는 브리핑이 소유한 값 복사이므로 원본 평가가 사라져도 함께 남는다.
        #expect(try ctx.fetch(FetchDescriptor<BriefingRiskItemSnapshot>()).count == 1)
    }
}
