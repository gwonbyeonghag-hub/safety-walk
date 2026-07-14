import Testing
import Foundation
import SwiftData
import SafetyWalkCore
@testable import 현장_안전_지킴이

// WO-2b: checklist seeding from a completed Inspection + JSA step ordering,
// verified on the real SwiftData stack (in-memory).

@MainActor
@Suite("RiskAssessment methods 2/2 — checklist seed + JSA order (WO-2b)")
struct RiskAssessmentMethodsTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private func completedInspection(in ctx: ModelContext) -> Inspection {
        let insp = Inspection(siteId: UUID(), siteName: "현장A",
                              inspectorName: "점검자", templateId: "t")
        insp.status = .completed
        ctx.insert(insp)
        return insp
    }

    @Test func checklistSeedTakesOnlyFailItems() throws {
        let ctx = try makeContext()
        let insp = completedInspection(in: ctx)
        let pass = ChecklistItem(inspectionId: insp.id, templateItemId: "p",
                                 title: "k.pass", category: "k.cat", sortOrder: 0)
        pass.result = .pass
        let fail1 = ChecklistItem(inspectionId: insp.id, templateItemId: "f1",
                                  title: "k.fail1", category: "k.cat", sortOrder: 1)
        fail1.result = .fail
        let fail2 = ChecklistItem(inspectionId: insp.id, templateItemId: "f2",
                                  title: "k.fail2", category: "k.cat", sortOrder: 2)
        fail2.result = .fail
        for ci in [pass, fail1, fail2] { ctx.insert(ci); insp.items?.append(ci) }

        let vm = RiskAssessmentViewModel()
        vm.method = .checklist
        vm.seedFromInspection(insp)

        #expect(vm.linkedInspectionId == insp.id)
        #expect(vm.draftItems.count == 2)   // only the two Fail items
        // hazardDescription = L(title); L returns the raw key when untranslated.
        #expect(vm.draftItems.map(\.hazardDescription).sorted() == ["k.fail1", "k.fail2"])
        // LEGAL-0: no auto-confirmed level. No linked hazard → no suggestion either.
        #expect(vm.draftItems.allSatisfy { $0.directRiskLevel == nil })
        #expect(vm.draftItems.allSatisfy { $0.suggestedLevel == nil })
    }

    @Test func checklistSeedPersistsLinkAndUserSetLevel() throws {
        let ctx = try makeContext()
        let insp = completedInspection(in: ctx)
        let fail = ChecklistItem(inspectionId: insp.id, templateItemId: "f",
                                 title: "k.fail", category: "k.cat", sortOrder: 0)
        fail.result = .fail
        ctx.insert(fail); insp.items?.append(fail)

        let vm = RiskAssessmentViewModel()
        vm.method = .checklist
        vm.assessorName = "평가자"
        vm.selectedSite = { let s = Site(name: "현장A"); ctx.insert(s); return s }()
        vm.seedFromInspection(insp)

        // LEGAL-0: seeded item carries no auto level — the user must set one before saving.
        var d = try #require(vm.draftItems.first)
        #expect(d.directRiskLevel == nil)
        d.directRiskLevel = .medium
        vm.addOrUpdate(d)

        try vm.save(context: ctx)

        let saved = try ctx.fetch(FetchDescriptor<RiskAssessment>())
            .first { $0.method == .checklist }
        #expect(saved?.linkedInspectionId == insp.id)
        let item = (saved?.items ?? []).first
        #expect(item?.riskLevel == .medium)        // user's direct choice persisted
        #expect(item?.likelihood == nil)
    }

    @Test func jsaPersistsStepOrder() throws {
        let ctx = try makeContext()
        let vm = RiskAssessmentViewModel()
        vm.method = .jsa
        vm.assessorName = "평가자"
        vm.selectedSite = { let s = Site(name: "현장C"); ctx.insert(s); return s }()
        for name in ["단계1", "단계2", "단계3"] {
            var d = RiskAssessmentViewModel.DraftItem()
            d.taskDescription = name
            d.likelihood = 1; d.severity = 1   // jsa → frequency×severity
            vm.addOrUpdate(d)
        }
        try vm.save(context: ctx)

        let saved = try ctx.fetch(FetchDescriptor<RiskAssessment>())
            .first { $0.method == .jsa }
        let items = (saved?.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
        #expect(items.map(\.sortOrder) == [0, 1, 2])               // explicit order kept
        #expect(items.map(\.taskDescription) == ["단계1", "단계2", "단계3"])
        #expect(items.first?.likelihood == 1)                       // freq×severity stored
    }
}
