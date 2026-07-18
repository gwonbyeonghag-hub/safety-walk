import Testing
import Foundation
import SwiftData
import SafetyWalkCore
@testable import 현장_안전_지킴이

// End-to-end data-path verification on the real SwiftData stack (in-memory):
// RiskAssessmentViewModel create → resolve risk → save → query back.
// Confirms CloudKit-ready @Model persistence and method-specific risk resolution.

@MainActor
@Suite("RiskAssessment persistence (SwiftData)")
struct RiskAssessmentPersistenceTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    /// A persisted site to satisfy the V3 site requirement (SCHEMA_V3 §4.1).
    private func seededSite(in ctx: ModelContext) -> Site {
        let site = Site(name: "테스트현장")
        ctx.insert(site)
        return site
    }

    @Test func frequencySeverityPersistsDerivedBand() throws {
        let ctx = try makeContext()
        let vm = RiskAssessmentViewModel()
        vm.method = .frequencySeverity
        vm.kind = .regular
        vm.assessorName = "Tester"
        vm.jurisdiction = .us                     // LEGAL-2d-PATH §3
        vm.selectedSite = seededSite(in: ctx)

        var item = RiskAssessmentViewModel.DraftItem()
        item.taskDescription = "용접 작업"
        item.hazardDescription = "화상"
        item.likelihood = 2
        item.severity = 3                 // score 6 → high
        vm.addOrUpdate(item)

        try vm.save(context: ctx)

        let all = try ctx.fetch(FetchDescriptor<RiskAssessment>())
        #expect(all.count == 1)
        let saved = all[0]
        #expect(saved.method == .frequencySeverity)
        #expect(saved.assessorName == "Tester")

        let items = saved.items ?? []
        #expect(items.count == 1)
        #expect(items[0].likelihood == 2)
        #expect(items[0].severity == 3)
        #expect(items[0].riskLevel == .high)   // derived from the matrix
    }

    @Test func threeLevelPersistsDirectLevelWithNilScores() throws {
        let ctx = try makeContext()
        let vm = RiskAssessmentViewModel()
        vm.method = .threeLevel
        vm.kind = .initial
        vm.assessorName = "Tester"
        vm.jurisdiction = .us                     // LEGAL-2d-PATH §3
        vm.selectedSite = seededSite(in: ctx)

        var item = RiskAssessmentViewModel.DraftItem()
        item.taskDescription = "고소 작업"
        item.hazardDescription = "추락"           // LEGAL-2d-PATH §4: 비공백 필수
        item.directRiskLevel = .medium
        vm.addOrUpdate(item)

        try vm.save(context: ctx)

        let saved = try ctx.fetch(FetchDescriptor<RiskAssessment>())[0]
        #expect(saved.method == .threeLevel)
        #expect(saved.kind == .initial)

        let it = (saved.items ?? [])[0]
        #expect(it.riskLevel == .medium)       // user's direct choice
        #expect(it.likelihood == nil)          // not frequency×severity
        #expect(it.severity == nil)
    }

    @Test func saveRequiresSiteAssessorItemAndResolvedRisk() throws {
        let vm = RiskAssessmentViewModel()
        vm.method = .threeLevel
        vm.assessorName = ""
        vm.jurisdiction = .us                     // LEGAL-2d-PATH §3
        #expect(vm.canSave == false)           // no site, no assessor, no items
        vm.selectedSite = Site(name: "현장")    // SCHEMA_V3 §4.1: site required
        vm.assessorName = "Tester"
        vm.jurisdiction = .us                     // LEGAL-2d-PATH §3
        #expect(vm.canSave == false)           // still no items

        var item = RiskAssessmentViewModel.DraftItem(taskDescription: "x")
        item.hazardDescription = "위험요인 x"      // LEGAL-2d-PATH §4: 비공백 필수
        vm.addOrUpdate(item)
        #expect(vm.canSave == false)           // LEGAL-0: item present but 미평가 → still blocked

        item.directRiskLevel = .high
        vm.addOrUpdate(item)
        #expect(vm.canSave == true)            // site + assessor + item + resolved risk

        vm.selectedSite = nil
        #expect(vm.canSave == false)           // dropping the site blocks save again
    }
}
