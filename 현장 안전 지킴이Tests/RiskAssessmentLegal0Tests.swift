import Testing
import Foundation
import SwiftData
import SafetyWalkCore
@testable import 현장_안전_지킴이

// LEGAL-0: "미입력=등급 없음, 자동 확정 금지, 저장 실패는 침묵 금지."
// Verifies the risk-input safety semantics on the real create-flow view model.

@MainActor
@Suite("RiskAssessment LEGAL-0 — risk-input safety")
struct RiskAssessmentLegal0Tests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    // ① freq×severity 값 미입력 → resolvedLevel == nil (자동 Low 안 됨).
    @Test func freqSeverityWithNoInputResolvesToNil() {
        let vm = RiskAssessmentViewModel()
        vm.method = .frequencySeverity
        let d = RiskAssessmentViewModel.DraftItem()   // likelihood/severity nil
        #expect(vm.resolvedLevel(for: d) == nil)      // NOT auto-.low
        #expect(vm.score(for: d) == nil)
    }

    // 3단계도 미선택이면 nil (자동 Low 안 됨).
    @Test func threeLevelWithNoChoiceResolvesToNil() {
        let vm = RiskAssessmentViewModel()
        vm.method = .threeLevel
        let d = RiskAssessmentViewModel.DraftItem()   // directRiskLevel nil
        #expect(vm.resolvedLevel(for: d) == nil)
    }

    // ② 체크리스트 부적합 시드(연결 위험요인 있음) → directRiskLevel == nil + suggestedLevel 세팅.
    @Test func checklistSeedSuggestsButDoesNotConfirm() throws {
        let ctx = try makeContext()
        let insp = Inspection(siteId: UUID(), siteName: "현장A",
                              inspectorName: "점검자", templateId: "t")
        insp.status = .completed
        ctx.insert(insp)

        let hazard = Hazard(siteId: insp.siteId, location: "개구부", type: .fallRisk,
                            riskLevel: .high, hazardDescription: "안전난간 미설치",
                            inspectionId: insp.id)
        ctx.insert(hazard); insp.hazards?.append(hazard)

        let ci = ChecklistItem(inspectionId: insp.id, templateItemId: "f",
                               title: "k.fail", category: "k.cat", sortOrder: 0)
        ci.result = .fail
        ci.linkedHazardId = hazard.id
        ctx.insert(ci); insp.items?.append(ci)

        let vm = RiskAssessmentViewModel()
        vm.method = .checklist
        vm.seedFromInspection(insp)

        let d = try #require(vm.draftItems.first)
        #expect(d.directRiskLevel == nil)             // 자동 확정 금지
        #expect(d.suggestedLevel == .high)            // 참고값만 (연결 위험요인 등급)
        #expect(vm.resolvedLevel(for: d) == nil)      // 미평가로 표시됨
    }

    // ③ 항목 하나라도 위험도 미입력 → canSave == false.
    @Test func anyUnassessedItemBlocksSave() {
        let vm = RiskAssessmentViewModel()
        vm.method = .threeLevel
        vm.assessorName = "평가자"
        vm.selectedSite = Site(name: "현장")           // SCHEMA_V3 §4.1: site required
        vm.jurisdiction = .us                          // LEGAL-2d-PATH §3: 관할 확인은 저장 전제

        var assessed = RiskAssessmentViewModel.DraftItem(taskDescription: "a")
        assessed.hazardDescription = "위험요인 a"       // LEGAL-2d-PATH §4: 비공백 필수
        assessed.directRiskLevel = .high
        vm.addOrUpdate(assessed)
        #expect(vm.canSave == true)                   // site + one fully-assessed item

        var unassessed = RiskAssessmentViewModel.DraftItem(taskDescription: "b")
        unassessed.hazardDescription = "위험요인 b"
        vm.addOrUpdate(unassessed)                    // no risk level
        #expect(vm.canSave == false)                  // one 미평가 blocks the whole save
    }

    // ④ 저장 경로가 미평가 항목을 만나면 throw + 아무것도 persist 안 됨.
    //    (호출부 do/catch는 이 throw를 받아 화면을 유지한다 — RiskAssessmentCreateView.)
    @Test func saveThrowsAndPersistsNothingWhenIncomplete() throws {
        let ctx = try makeContext()
        let vm = RiskAssessmentViewModel()
        vm.method = .threeLevel
        vm.assessorName = "평가자"
        vm.addOrUpdate(RiskAssessmentViewModel.DraftItem(taskDescription: "미평가 항목"))

        #expect(throws: RiskAssessmentViewModel.SaveError.self) {
            try vm.save(context: ctx)
        }
        // 침묵 저장 없음: 부분 insert가 남지 않는다.
        let persisted = try ctx.fetch(FetchDescriptor<RiskAssessment>())
        #expect(persisted.isEmpty)
    }
}
