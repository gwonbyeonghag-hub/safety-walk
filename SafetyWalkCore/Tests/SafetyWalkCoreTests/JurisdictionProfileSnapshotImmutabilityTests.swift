import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-TBM-4 §2.3 — 평가·브리핑이 든 관할/프로필 값 스냅샷(jurisdictionSnapshot·
// industryProfileSnapshot·briefingProfile)은 생성 시점에 값으로 복사되며, 이후 그 값의 출처(Site)를
// 바꿔도 흔들리지 않는다. `RiskAssessment`/`SafetyBriefing` 은 `siteId: UUID?` 로만 Site 를 참조할 뿐
// 관계가 아니므로(cascade 없음, SCHEMA_V3), Site 를 수정해도 이미 만든 값 스냅샷은 재계산되지 않는다.
// (Program→Assessment 값 복사 경로는 아직 어떤 Core 원자 연산도 배선하지 않아 — `AssessmentDraft` 에
// programId/industryProfile 입력 자체가 없다 — 실제 경로로 재현 가능한 범위로 좁혔다.)

@Suite("관할/프로필 값 스냅샷 불변성 — Site 변경에 흔들리지 않는다 (LEGAL-TBM-4 §2.3)")
struct JurisdictionProfileSnapshotImmutabilityTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true)

    @Test("Site 이름을 바꿔도 이미 만든 평가의 siteName·jurisdictionSnapshot·industryProfileSnapshot 값은 그대로다")
    func siteRenameDoesNotAffectAssessmentSnapshot() throws {
        let ctx = try makeContext()
        let site = Site(name: "1공장")
        ctx.insert(site)
        try ctx.save()

        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: site.id, siteName: site.name, assessorName: "홍길동",
                                jurisdictionSnapshot: .kr, industryProfileSnapshot: .construction)
        ctx.insert(ra)
        try ctx.save()

        site.name = "2공장(개명)"
        try ctx.save()

        #expect(ra.siteName == "1공장")
        #expect(ra.jurisdictionSnapshot == .kr)
        #expect(ra.industryProfileSnapshot == .construction)
    }

    @Test("Site 이름을 바꿔도 이미 만든 브리핑의 siteName·briefingProfile 값은 그대로다")
    func siteRenameDoesNotAffectBriefingSnapshot() throws {
        let ctx = try makeContext()
        let site = Site(name: "1공장")
        ctx.insert(site)
        try ctx.save()

        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: site.id, siteName: site.name, briefingProfile: .krTBM), in: ctx)

        site.name = "2공장(개명)"
        try ctx.save()

        #expect(briefing.siteName == "1공장")
        #expect(briefing.briefingProfile == .krTBM)
    }

    @Test("평가 수명주기(시작→확정) 내내 jurisdictionSnapshot·industryProfileSnapshot 은 변하지 않는다")
    func jurisdictionAndProfileSnapshotAreConstantAcrossAssessmentLifecycle() throws {
        let ctx = try makeContext()
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                                jurisdictionSnapshot: .kr, industryProfileSnapshot: .electric,
                                scheduledAt: when)
        ctx.insert(ra)
        try ctx.save()
        try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                         target: "전 근로자", ownerName: "홍길동", at: when, context: ctx)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        #expect(ra.jurisdictionSnapshot == .kr)
        #expect(ra.industryProfileSnapshot == .electric)

        let item = RiskAssessmentItem(taskDescription: "운반", hazardDescription: "협착",
                                      likelihood: 1, severity: 1, riskLevel: .low)
        item.riskAssessment = ra
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        ctx.insert(item)
        ra.items = [item]
        try ctx.save()
        try AssessmentFinalization.finalize(ra, now: when, in: ctx)

        #expect(ra.jurisdictionSnapshot == .kr)
        #expect(ra.industryProfileSnapshot == .electric)
    }

    @Test("브리핑 수명주기(진행→확정) 내내 briefingProfile 은 변하지 않는다")
    func briefingProfileIsConstantAcrossBriefingLifecycle() throws {
        let ctx = try makeContext()
        let briefing = try BriefingAuthoring.create(
            BriefingDraft(siteId: UUID(), siteName: "1공장", briefingProfile: .usElectric), in: ctx)
        #expect(briefing.briefingProfile == .usElectric)

        try BriefingLifecycle.conduct(briefing, briefingContent: "오늘 작업 전달",
                                      sourceAssessment: nil, now: when, in: ctx)
        #expect(briefing.briefingProfile == .usElectric)

        try BriefingLifecycle.finalize(briefing, now: when, in: ctx)
        #expect(briefing.briefingProfile == .usElectric)
    }
}
