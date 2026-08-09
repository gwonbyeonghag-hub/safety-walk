import Testing
import Foundation
import SwiftData
import SafetyWalkCore
@testable import 현장_안전_지킴이

// WO LEGAL-3B §A: US(.global)이 이제 템플릿 2개(General Industry/Construction)를 내놓으므로
// "첫 템플릿 자동선택 금지"가 실제로 지켜지는지, KR의 기존 자동선택은 그대로인지, 선택한 템플릿의
// 정확한 templateId/localization key가 Inspection·ChecklistItem에 그대로 남는지를 고정한다.

@MainActor
@Suite("StartInspectionViewModel — US 템플릿 명시 선택 (WO LEGAL-3B)")
struct StartInspectionViewModelTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func makeSite(in context: ModelContext) -> Site {
        let site = Site(name: "1공장")
        context.insert(site)
        return site
    }

    // MARK: - loadTemplates() 자동선택 정책

    @Test func koreaStillAutoSelectsItsSingleTemplate() {
        let originalRegion = RegionProfileStore.get()
        defer { RegionProfileStore.set(originalRegion) }
        RegionProfileStore.set(.korea)

        let vm = StartInspectionViewModel()
        vm.loadTemplates()

        #expect(vm.selectedTemplate?.regionProfile == .korea)
        #expect(vm.canProceedFromTemplate)
    }

    @Test func usRegionStartsWithNoTemplateSelected() {
        let originalRegion = RegionProfileStore.get()
        defer { RegionProfileStore.set(originalRegion) }
        RegionProfileStore.set(.global)

        let vm = StartInspectionViewModel()
        vm.loadTemplates()

        #expect(vm.selectedTemplate == nil)
        #expect(!vm.canProceedFromTemplate)
    }

    @Test func usRegionOffersExactlyTwoDistinctTemplatesInTheFullList() {
        let originalRegion = RegionProfileStore.get()
        defer { RegionProfileStore.set(originalRegion) }
        RegionProfileStore.set(.global)

        let vm = StartInspectionViewModel()
        vm.loadTemplates()

        let usTemplates = vm.templates.filter { $0.regionProfile == .global }
        #expect(usTemplates.count == 2)
        #expect(Set(usTemplates.map(\.id)) == ["us-federal-general-industry-v1", "us-federal-construction-v1"])
    }

    @Test func explicitlyPickingAUSTemplateEnablesProceeding() {
        let originalRegion = RegionProfileStore.get()
        defer { RegionProfileStore.set(originalRegion) }
        RegionProfileStore.set(.global)

        let vm = StartInspectionViewModel()
        vm.loadTemplates()
        #expect(!vm.canProceedFromTemplate)

        vm.selectedTemplate = vm.templates.first { $0.id == "us-federal-construction-v1" }
        #expect(vm.canProceedFromTemplate)
    }

    // MARK: - 템플릿 변경 시 category 선택 초기화 (두 US 템플릿 간 전환)

    @Test func switchingBetweenTheTwoUSTemplatesResetsCategorySelection() throws {
        let vm = StartInspectionViewModel()
        vm.templates = (try? ChecklistTemplateLoader().load(for: .global)) ?? []
        let general = try #require(vm.templates.first { $0.id == "us-federal-general-industry-v1" })
        let construction = try #require(vm.templates.first { $0.id == "us-federal-construction-v1" })

        vm.selectedTemplate = general
        vm.selectAllCategories()
        #expect(!vm.selectedCategoryKeys.isEmpty)

        vm.selectedTemplate = construction
        #expect(vm.selectedCategoryKeys.isEmpty,
                "선택한 템플릿을 바꾸면 이전 템플릿의 category 선택이 새 템플릿으로 넘어오면 안 된다")
    }

    // MARK: - Inspection 생성 — 정확한 templateId·titleKey

    @Test func createInspectionStampsTheExactSelectedUSTemplateId() throws {
        let context = try makeContext()
        let site = makeSite(in: context)

        let vm = StartInspectionViewModel()
        vm.templates = (try? ChecklistTemplateLoader().load(for: .global)) ?? []
        let construction = try #require(vm.templates.first { $0.id == "us-federal-construction-v1" })
        vm.selectedTemplate = construction
        vm.selectedSite = site
        vm.selectAllCategories()

        vm.createInspection(context: context)

        let inspections = try context.fetch(FetchDescriptor<Inspection>())
        let inspection = try #require(inspections.first)
        #expect(inspection.templateId == "us-federal-construction-v1")

        let items = try context.fetch(FetchDescriptor<ChecklistItem>())
        #expect(!items.isEmpty)
        // 항목의 title/category 는 템플릿의 원본 titleKey 그대로 저장된다(로컬라이즈 문자열이 아님).
        let allTemplateItemKeys = Set(construction.categories.flatMap { $0.items.map(\.titleKey) })
        for item in items {
            #expect(allTemplateItemKeys.contains(item.title),
                    "저장된 ChecklistItem.title '\(item.title)' 이 선택한 템플릿의 titleKey 집합에 없다")
        }
    }

    // MARK: - Federal notice 정책이 실제 로드된 US 템플릿 id 와 어긋나지 않는다

    @Test func federalNoticePolicyMatchesTheRealLoadedTemplateIds() throws {
        let usTemplates = try ChecklistTemplateLoader().load(for: .global)
        for template in usTemplates {
            #expect(ChecklistTemplatePolicy.showsFederalNotice(forTemplateId: template.id),
                    "실제 로드된 US 템플릿 '\(template.id)' 가 정책 스위치와 어긋난다")
        }

        let koreaTemplates = try ChecklistTemplateLoader().load(for: .korea)
        for template in koreaTemplates {
            #expect(!ChecklistTemplatePolicy.showsFederalNotice(forTemplateId: template.id),
                    "한국 템플릿 '\(template.id)' 에 Federal 경고가 켜지면 안 된다")
        }
    }
}
