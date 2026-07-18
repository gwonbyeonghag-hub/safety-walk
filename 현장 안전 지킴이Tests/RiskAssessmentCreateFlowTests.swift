import Testing
import Foundation
import SwiftData
import SafetyWalkCore
@testable import 현장_안전_지킴이

// WO LEGAL-2c (반송 2차) — the create flow's 개선조치 rules on the real SwiftData stack (in-memory):
// a newly created action is always `.notStarted` with empty 이행일·개선후위험도·효과확인; an entirely
// empty action makes no action; and entering action data (담당/기한) without a 감소대책 blocks the whole
// save (no partial persist). Uses swift-testing @MainActor @Suite like RiskAssessmentPersistenceTests.
//
// WO LEGAL-2d-PATH: 저장은 이제 Core 의 단일 원자 연산(`AssessmentAuthoring.create`)을 지나며 결과는
// **항상 `.planned`** 다(즉시 시작 경로 제거). 검증 오류도 Core 의 `AssessmentAuthoringError` 로 온다.

@MainActor
@Suite("RiskAssessment create flow — 개선조치 rules (LEGAL-2c 2차)")
struct RiskAssessmentCreateFlowTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    private func makeVM(_ ctx: ModelContext) -> RiskAssessmentViewModel {
        let site = Site(name: "테스트 현장")
        ctx.insert(site)
        let vm = RiskAssessmentViewModel()
        vm.method = .threeLevel      // 3단계: directRiskLevel resolves the level
        vm.assessorName = "홍길동"
        vm.selectedSite = site
        vm.jurisdiction = .us        // 사용자가 확인한 관할 (US 는 일정 선택)
        return vm
    }

    private func draft(measure: String = "", responsible: String = "", hasDue: Bool = false)
        -> RiskAssessmentViewModel.DraftItem {
        var d = RiskAssessmentViewModel.DraftItem()
        d.taskDescription = "작업"
        d.hazardDescription = "유해위험요인"   // Core 가 비공백을 요구한다(LEGAL-2d-PATH §4)
        d.directRiskLevel = .low
        d.reductionMeasure = measure
        d.responsibleName = responsible
        d.hasDueDate = hasDue
        return d
    }

    @Test func createdActionIsNotStarted() throws {
        let ctx = try makeContext()
        let vm = makeVM(ctx)
        vm.draftItems = [draft(measure: "난간 설치")]
        try vm.save(context: ctx)
        // 생성 결과는 항상 planned — 저장하자마자 시작하지 않는다.
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessment>()).first?.status == .planned)
        let action = try #require(try ctx.fetch(FetchDescriptor<CorrectiveAction>()).first)
        #expect(action.status == .notStarted)
        #expect(action.implementedAt == nil)
        #expect(action.postRiskLevel == nil)
        #expect(action.effectivenessResult == nil)
        #expect(action.measure == "난간 설치")
    }

    @Test func emptyActionCreatesNoAction() throws {
        let ctx = try makeContext()
        let vm = makeVM(ctx)
        vm.draftItems = [draft()]   // no measure, no responsible, no due
        try vm.save(context: ctx)
        #expect(try ctx.fetch(FetchDescriptor<CorrectiveAction>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessment>()).count == 1)
    }

    @Test func partialActionWithoutMeasureBlocksSave() throws {
        let ctx = try makeContext()
        let vm = makeVM(ctx)
        vm.draftItems = [draft(responsible: "김담당")]   // action data, but no 감소대책
        #expect(throws: AssessmentAuthoringError.incompleteAction) {
            try vm.save(context: ctx)
        }
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessment>()).isEmpty)   // no partial save
        #expect(try ctx.fetch(FetchDescriptor<CorrectiveAction>()).isEmpty)
    }
}
