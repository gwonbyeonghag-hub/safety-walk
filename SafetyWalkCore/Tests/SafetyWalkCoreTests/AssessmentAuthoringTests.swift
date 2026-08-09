import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2d-PATH §3·§4 — 평가 생성은 Core 의 단일 원자 연산이다.
// 모든 신규 평가는 항상 `.planned` 로 태어나고(즉시 시작 경로 없음), 관할은 사용자가 확인한 값만
// 값 복사되며, 검증·commit 실패 시 store 와 메모리 어디에도 평가·항목·조치가 남지 않는다.

@Suite("AssessmentAuthoring — 원자 생성 + 관할 계약 (LEGAL-2d-PATH)")
struct AssessmentAuthoringTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let scheduled = Date(timeIntervalSince1970: 1_700_600_000)

    /// `industryProfile` defaults to `.general` so every existing `.us` fixture in this suite stays
    /// valid without threading the new WO LEGAL-3A parameter through each call site — the tests that
    /// specifically exercise the missing-industry gate pass `industryProfile: nil` explicitly.
    private func draft(jurisdiction: JurisdictionCode?,
                       industryProfile: IndustryProfileCode? = .general,
                       scheduledAt: Date? = nil,
                       items: [AssessmentDraft.ItemDraft] = []) -> AssessmentDraft {
        AssessmentDraft(
            kind: .regular, method: .frequencySeverity,
            siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
            jurisdiction: jurisdiction, industryProfile: industryProfile,
            scheduledAt: scheduledAt, items: items)
    }

    private func itemDraft(task: String = "굴착", hazard: String = "붕괴",
                           likelihood: Int? = 1, severity: Int? = 1,
                           riskLevel: RiskLevel? = .low,
                           measure: String? = nil) -> AssessmentDraft.ItemDraft {
        AssessmentDraft.ItemDraft(taskDescription: task, hazardDescription: hazard,
                                  currentControls: "기존 안전난간",
                                  likelihood: likelihood, severity: severity,
                                  riskLevel: riskLevel, measure: measure)
    }

    // MARK: - 항상 planned 로 태어난다

    @Test("신규 평가는 항상 planned 이며 항목·조치와 함께 한 번에 저장된다")
    func createsPlannedAssessmentWithItems() throws {
        let ctx = try makeContext()
        let ra = try AssessmentAuthoring.create(
            draft(jurisdiction: .us, items: [itemDraft(), itemDraft(task: "용접", hazard: "화재",
                                                       measure: "불티방지포")]),
            now: when, in: ctx)

        #expect(ra.status == .planned)          // 즉시 시작 경로 없음
        #expect(ra.criteria == nil)             // 기준은 시작할 때 잠긴다
        #expect(ra.assessedAt == nil)
        #expect((ra.items ?? []).count == 2)
        // sortOrder 는 입력 순서를 따른다.
        let items = (ra.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
        #expect(items.map(\.taskDescription) == ["굴착", "용접"])
        #expect(items[0].riskLevel == .low)
        // 기준 이내/초과 결정은 생성 시 채우지 않는다 (사용자가 상세에서 확인).
        #expect(items.allSatisfy { $0.criteriaDecision == nil })
        // 감소대책이 있는 항목만 개선조치를 갖는다 (빈 조치 양산 금지).
        #expect((items[0].correctiveActions ?? []).isEmpty)
        #expect((items[1].correctiveActions ?? []).count == 1)
        #expect(items[1].correctiveActions?.first?.status == .notStarted)

        // 저장까지 끝났다 — 다시 조회해도 남아 있다.
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessment>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentItem>()).count == 2)
    }

    @Test("항목 없이 헤더만으로도 planned 평가를 만들 수 있다 (평가 계획 경로)")
    func createsHeaderOnlyPlannedAssessment() throws {
        let ctx = try makeContext()
        let ra = try AssessmentAuthoring.create(
            draft(jurisdiction: .kr, scheduledAt: scheduled), now: when, in: ctx)

        #expect(ra.status == .planned)
        #expect((ra.items ?? []).isEmpty)
        #expect(ra.scheduledAt == scheduled)
    }

    // MARK: - 관할 계약

    @Test("확인한 관할은 값 스냅샷으로 복사된다")
    func confirmedJurisdictionIsValueCopied() throws {
        let ctx = try makeContext()
        let kr = try AssessmentAuthoring.create(draft(jurisdiction: .kr, scheduledAt: scheduled),
                                                now: when, in: ctx)
        let us = try AssessmentAuthoring.create(draft(jurisdiction: .us), now: when, in: ctx)
        #expect(kr.jurisdictionSnapshot == .kr)
        #expect(us.jurisdictionSnapshot == .us)
    }

    @Test("관할 미설정(nil) 평가도 만들 수 있고 '관할 미설정'으로 유지된다")
    func unsetJurisdictionRemainsUnset() throws {
        let ctx = try makeContext()
        let ra = try AssessmentAuthoring.create(draft(jurisdiction: nil), now: when, in: ctx)
        #expect(ra.jurisdictionSnapshot == nil)
        #expect(SharingEventPolicy.jurisdictionState(ra) == .unset)
    }

    @Test("KR 관할은 일정이 필수이고, US 는 일정 없이도 만들 수 있다")
    func krRequiresScheduleUSDoesNot() throws {
        let ctx = try makeContext()
        #expect(throws: AssessmentAuthoringError.missingScheduleForJurisdiction) {
            try AssessmentAuthoring.create(draft(jurisdiction: .kr), now: when, in: ctx)
        }
        #expect(throws: Never.self) {
            try AssessmentAuthoring.create(draft(jurisdiction: .us), now: when, in: ctx)
        }
        // 실패한 KR 생성은 아무것도 남기지 않는다.
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessment>()).count == 1)
    }

    @Test("RegionProfile 은 관할을 추천만 하고 자동 확정하지 않는다")
    func regionProfileOnlySuggests() throws {
        #expect(JurisdictionPolicy.suggested(for: .korea) == .kr)
        #expect(JurisdictionPolicy.suggested(for: .global) == .us)
        // 추천은 값일 뿐 — 생성 입력의 기본값은 nil 이며 자동으로 채워지지 않는다.
        let untouched = AssessmentDraft(kind: .regular, method: .frequencySeverity,
                                        siteId: UUID(), siteName: "1공장", assessorName: "홍길동")
        #expect(untouched.jurisdiction == nil)
    }

    @Test("KR 관할만 일정을 요구한다 — 화면이 저장 버튼을 가늠하는 단일 소스")
    func scheduleRequirementIsJurisdictionDriven() {
        #expect(JurisdictionPolicy.requiresSchedule(.kr))
        #expect(!JurisdictionPolicy.requiresSchedule(.us))
        #expect(!JurisdictionPolicy.requiresSchedule(nil))
    }

    // MARK: - 업종 계약 (WO LEGAL-3A)

    @Test("US 관할만 업종을 요구한다 — 화면이 저장 버튼을 가늠하는 단일 소스")
    func industryRequirementIsJurisdictionDriven() {
        #expect(JurisdictionPolicy.requiresIndustry(.us))
        #expect(!JurisdictionPolicy.requiresIndustry(.kr))
        #expect(!JurisdictionPolicy.requiresIndustry(nil))
    }

    @Test("US 관할은 업종이 없으면 생성이 거부되고 아무것도 남지 않는다")
    func usRequiresIndustryProfile() throws {
        let ctx = try makeContext()
        #expect(throws: AssessmentAuthoringError.missingIndustryForJurisdiction) {
            try AssessmentAuthoring.create(draft(jurisdiction: .us, industryProfile: nil),
                                           now: when, in: ctx)
        }
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessment>()).isEmpty)
    }

    @Test("US + 업종을 함께 지정하면 스냅샷에 값으로 복사된다")
    func usWithIndustryIsSnapshotted() throws {
        let ctx = try makeContext()
        let ra = try AssessmentAuthoring.create(
            draft(jurisdiction: .us, industryProfile: .construction), now: when, in: ctx)
        #expect(ra.industryProfileSnapshot == .construction)
    }

    @Test("KR·미설정 관할은 업종이 없어도 생성된다 — 자동 확정하지 않을 뿐 요구하지도 않는다")
    func nonUSDoesNotRequireIndustry() throws {
        let ctx = try makeContext()
        #expect(throws: Never.self) {
            try AssessmentAuthoring.create(
                draft(jurisdiction: .kr, industryProfile: nil, scheduledAt: scheduled),
                now: when, in: ctx)
        }
        #expect(throws: Never.self) {
            try AssessmentAuthoring.create(draft(jurisdiction: nil, industryProfile: nil),
                                           now: when, in: ctx)
        }
    }

    @Test("업종 선택을 나중에 바꿔도 이미 저장된 평가의 industryProfileSnapshot 은 그대로다")
    func industryProfileSnapshotIsImmutableAfterCreation() throws {
        let ctx = try makeContext()
        var d = draft(jurisdiction: .us, industryProfile: .construction)
        let ra = try AssessmentAuthoring.create(d, now: when, in: ctx)
        #expect(ra.industryProfileSnapshot == .construction)

        // 같은 초안 값을 바꿔 새 평가를 만들어도 기존 평가의 스냅샷은 흔들리지 않는다 — 매 생성은
        // 그 시점 값의 독립적인 값 복사다(§4.1 생성자 계약, jurisdictionSnapshot 과 같은 불변성).
        d.industryProfile = .general
        let ra2 = try AssessmentAuthoring.create(d, now: when, in: ctx)
        #expect(ra.industryProfileSnapshot == .construction)
        #expect(ra2.industryProfileSnapshot == .general)
    }

    // MARK: - 검증 (저장 전 차단 · 유령 데이터 0)

    @Test("빈 현장명·평가자·작업·위험요인·미평가 항목은 생성을 차단하고 아무것도 남기지 않는다")
    func invalidDraftsAreRefusedWithoutTrace() throws {
        let ctx = try makeContext()

        var noSiteName = draft(jurisdiction: .us); noSiteName.siteName = "  "
        #expect(throws: AssessmentAuthoringError.emptySiteName) {
            try AssessmentAuthoring.create(noSiteName, now: when, in: ctx)
        }
        var noAssessor = draft(jurisdiction: .us); noAssessor.assessorName = " "
        #expect(throws: AssessmentAuthoringError.emptyAssessorName) {
            try AssessmentAuthoring.create(noAssessor, now: when, in: ctx)
        }
        #expect(throws: AssessmentAuthoringError.emptyTaskDescription) {
            try AssessmentAuthoring.create(draft(jurisdiction: .us, items: [itemDraft(task: "  ")]),
                                           now: when, in: ctx)
        }
        #expect(throws: AssessmentAuthoringError.emptyHazardDescription) {
            try AssessmentAuthoring.create(draft(jurisdiction: .us, items: [itemDraft(hazard: "")]),
                                           now: when, in: ctx)
        }
        #expect(throws: AssessmentAuthoringError.unassessedItem) {
            try AssessmentAuthoring.create(
                draft(jurisdiction: .us, items: [itemDraft(riskLevel: nil)]), now: when, in: ctx)
        }

        // 어느 실패도 store 에 흔적을 남기지 않는다.
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessment>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentItem>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<CorrectiveAction>()).isEmpty)
    }

    // MARK: - commit 실패 원복 (store + 메모리)

    @Test("commit 실패 시 평가·항목·조치가 store 와 메모리 양쪽에서 사라진다")
    func failedCommitLeavesNothingBehind() throws {
        let ctx = try makeContext()
        // 먼저 정상 평가 1건을 만들어 둔다 — 실패가 기존 데이터를 건드리지 않아야 한다.
        let existing = try AssessmentAuthoring.create(draft(jurisdiction: .us, items: [itemDraft()]),
                                                      now: when, in: ctx)

        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try AssessmentAuthoring.create(
                draft(jurisdiction: .us, items: [itemDraft(task: "유령작업", measure: "유령대책")]),
                now: when, in: ctx, commit: { throw Boom() })
        }

        // store: 기존 1건만 남는다.
        let stored = try ctx.fetch(FetchDescriptor<RiskAssessment>())
        #expect(stored.count == 1)
        #expect(stored.first === existing)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentItem>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<CorrectiveAction>()).isEmpty)

        // 메모리: 유령 항목·조치가 어디에도 없다.
        #expect(!(try ctx.fetch(FetchDescriptor<RiskAssessmentItem>()))
            .contains { $0.taskDescription == "유령작업" })
        #expect((existing.items ?? []).count == 1)
    }
}
