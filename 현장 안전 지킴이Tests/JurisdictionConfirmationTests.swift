import Testing
import Foundation
import SwiftData
import SafetyWalkCore
@testable import 현장_안전_지킴이

/// WO LEGAL-2d-PATH §3 — 관할은 **사용자가 확인한 값만** 기록된다.
/// 지역 프로파일은 추천만 하고, 확인 전에는 저장 자체가 막힌다.
@MainActor
@Suite("Jurisdiction 확인 계약 (LEGAL-2d-PATH)")
struct JurisdictionConfirmationTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func readyVM(_ ctx: ModelContext) -> RiskAssessmentViewModel {
        let site = Site(name: "테스트 현장")
        ctx.insert(site)
        let vm = RiskAssessmentViewModel()
        vm.method = .threeLevel
        vm.assessorName = "홍길동"
        vm.selectedSite = site
        var d = RiskAssessmentViewModel.DraftItem()
        d.taskDescription = "굴착"
        d.hazardDescription = "붕괴"
        d.directRiskLevel = .low
        vm.addOrUpdate(d)
        return vm
    }

    @Test("관할 선택은 비어 있는 상태로 시작한다 — 추천이 미리 채우지 않는다")
    func jurisdictionStartsUnselected() {
        #expect(RiskAssessmentViewModel().jurisdiction == nil)
    }

    @Test("관할을 확인하기 전에는 저장할 수 없다")
    func saveBlockedUntilJurisdictionConfirmed() throws {
        let ctx = try makeContext()
        let vm = readyVM(ctx)
        #expect(!vm.canSave)                    // 나머지 조건은 모두 충족했는데도 막힌다
        vm.jurisdiction = .us
        vm.industryProfile = .general            // WO LEGAL-3A: US 는 업종도 필요
        #expect(vm.canSave)
    }

    @Test("지역 프로파일은 추천만 하고 저장되는 값을 바꾸지 않는다")
    func regionProfileSuggestsButDoesNotDecide() throws {
        let ctx = try makeContext()
        // 프로파일이 Korea 여도 사용자가 US 를 고르면 US 가 저장된다 — 두 축은 독립이다.
        #expect(JurisdictionPolicy.suggested(for: .korea) == .kr)
        let vm = readyVM(ctx)
        vm.jurisdiction = .us
        vm.industryProfile = .construction       // WO LEGAL-3A
        try vm.save(context: ctx)

        let saved = try #require(try ctx.fetch(FetchDescriptor<RiskAssessment>()).first)
        #expect(saved.jurisdictionSnapshot == .us)
        #expect(saved.status == .planned)       // 저장은 planned 까지만
    }

    @Test("KR 을 고르면 일정이 필요하고, 일정이 있으면 저장된다")
    func krRequiresSchedule() throws {
        let ctx = try makeContext()
        let vm = readyVM(ctx)
        vm.jurisdiction = .kr
        // VM 은 KR 일 때 항상 일정을 함께 넘기므로 저장이 성립한다.
        try vm.save(context: ctx)
        let saved = try #require(try ctx.fetch(FetchDescriptor<RiskAssessment>()).first)
        #expect(saved.jurisdictionSnapshot == .kr)
        #expect(saved.scheduledAt != nil, "KR 평가는 일정이 값으로 저장돼야 한다")
    }

    @Test("US 평가는 일정 없이 저장된다")
    func usSavesWithoutSchedule() throws {
        let ctx = try makeContext()
        let vm = readyVM(ctx)
        vm.jurisdiction = .us
        vm.industryProfile = .general             // WO LEGAL-3A
        try vm.save(context: ctx)
        let saved = try #require(try ctx.fetch(FetchDescriptor<RiskAssessment>()).first)
        #expect(saved.scheduledAt == nil)
    }

    // MARK: - WO LEGAL-3A: 업종 확인 계약 (관할과 같은 패턴)

    @Test("US 관할은 업종을 확인하기 전에는 저장할 수 없다")
    func saveBlockedUntilIndustryConfirmedForUS() throws {
        let ctx = try makeContext()
        let vm = readyVM(ctx)
        vm.jurisdiction = .us
        #expect(!vm.canSave)                     // 관할은 있지만 업종이 없다
        vm.industryProfile = .construction
        #expect(vm.canSave)
    }

    @Test("KR 관할은 업종이 없어도 저장할 수 있다 — US 관할만 업종을 요구한다")
    func krDoesNotRequireIndustry() throws {
        let ctx = try makeContext()
        let vm = readyVM(ctx)
        vm.jurisdiction = .kr
        #expect(vm.canSave)                      // 업종 없이도 막히지 않는다(VM 이 일정은 항상 동봉)
    }

    @Test("US + 업종을 함께 저장하면 업종 스냅샷 값으로 복사된다")
    func usIndustryIsSnapshotted() throws {
        let ctx = try makeContext()
        let vm = readyVM(ctx)
        vm.jurisdiction = .us
        vm.industryProfile = .electric
        try vm.save(context: ctx)
        let saved = try #require(try ctx.fetch(FetchDescriptor<RiskAssessment>()).first)
        #expect(saved.industryProfileSnapshot == .electric)
    }
}
