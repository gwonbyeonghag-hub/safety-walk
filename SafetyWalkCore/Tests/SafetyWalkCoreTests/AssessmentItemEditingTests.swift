import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2d-PATH §4 — 항목 추가·수정·삭제.
// planned/inProgress 에서만 편집 가능하고 finalized/cancelled 에서는 잠긴다(LEGAL_2_ARCH §1 lock timing).
// inProgress 에서 위험 입력을 바꾸면 기존 update API 를 거쳐 기준확인 3필드가 무효화된다.

@Suite("AssessmentItemEditing — 항목 CRUD + 상태 잠금 (LEGAL-2d-PATH)")
struct AssessmentItemEditingTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true) // threshold 2

    private func plannedAssessment(in ctx: ModelContext,
                                   items: [AssessmentDraft.ItemDraft] = []) throws -> RiskAssessment {
        try AssessmentAuthoring.create(
            AssessmentDraft(kind: .regular, method: .frequencySeverity,
                            siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                            jurisdiction: .us, items: items),
            now: when, in: ctx)
    }

    private func startedAssessment(in ctx: ModelContext,
                                   items: [AssessmentDraft.ItemDraft] = []) throws -> RiskAssessment {
        let ra = try plannedAssessment(in: ctx, items: items)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        return ra
    }

    private func itemDraft(task: String = "굴착", hazard: String = "붕괴",
                           l: Int? = 1, s: Int? = 1, level: RiskLevel? = .low)
        -> AssessmentDraft.ItemDraft {
        AssessmentDraft.ItemDraft(taskDescription: task, hazardDescription: hazard,
                                  likelihood: l, severity: s, riskLevel: level)
    }

    // MARK: - add

    @Test("planned 평가에 항목을 추가할 수 있고 sortOrder 가 이어진다")
    func addsItemToPlannedAssessment() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, items: [itemDraft()])

        let added = try AssessmentItemEditing.add(
            to: ra, task: "용접", hazard: "화재", currentControls: "불티방지포",
            likelihood: 2, severity: 2, riskLevel: .medium, at: when, context: ctx)

        #expect((ra.items ?? []).count == 2)
        #expect(added.sortOrder == 1)                 // 기존 0 다음
        #expect(added.taskDescription == "용접")
        #expect(added.riskLevel == .medium)
        #expect(added.criteriaDecision == nil)        // 결정은 사용자가 따로 확인
        #expect(ra.updatedAt == when)
    }

    @Test("inProgress 평가에도 항목을 추가할 수 있다")
    func addsItemToInProgressAssessment() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx, items: [itemDraft()])
        try AssessmentItemEditing.add(to: ra, task: "운반", hazard: "협착",
                                      likelihood: 1, severity: 1, riskLevel: .low,
                                      at: when, context: ctx)
        #expect((ra.items ?? []).count == 2)
    }

    @Test("공백 작업·위험요인, 미평가 항목은 추가되지 않는다")
    func refusesInvalidItems() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)

        #expect(throws: AssessmentItemError.emptyTaskDescription) {
            try AssessmentItemEditing.add(to: ra, task: "  ", hazard: "붕괴",
                                          likelihood: 1, severity: 1, at: when, context: ctx)
        }
        #expect(throws: AssessmentItemError.emptyHazardDescription) {
            try AssessmentItemEditing.add(to: ra, task: "굴착", hazard: "",
                                          likelihood: 1, severity: 1, at: when, context: ctx)
        }
        // 빈도×강도 기법에서 가능성·중대성이 없으면 위험도를 해결할 수 없다 = 미평가.
        #expect(throws: AssessmentItemError.unassessedItem) {
            try AssessmentItemEditing.add(to: ra, task: "굴착", hazard: "붕괴",
                                          likelihood: nil, severity: nil, at: when, context: ctx)
        }
        #expect((ra.items ?? []).isEmpty)
    }

    // MARK: - 상태 잠금

    @Test("finalized 평가의 항목은 잠긴다 — 추가·수정·삭제 모두 거부")
    func finalizedAssessmentLocksItems() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx, items: [itemDraft()])
        let item = try #require(ra.items?.first)
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        try ctx.save()
        try AssessmentFinalization.finalize(ra, now: when, in: ctx)

        #expect(throws: AssessmentItemError.assessmentNotEditable) {
            try AssessmentItemEditing.add(to: ra, task: "추가", hazard: "위험",
                                          likelihood: 1, severity: 1, riskLevel: .low,
                                          at: when, context: ctx)
        }
        #expect(throws: AssessmentItemError.assessmentNotEditable) {
            try AssessmentItemEditing.update(item, in: ra, task: "수정", hazard: "붕괴",
                                             likelihood: 1, severity: 1, riskLevel: .low,
                                             at: when, context: ctx)
        }
        #expect(throws: AssessmentItemError.assessmentNotEditable) {
            try AssessmentItemEditing.remove(item, in: ra, at: when, context: ctx)
        }
        #expect((ra.items ?? []).count == 1)
        #expect(item.taskDescription == "굴착")
    }

    @Test("cancelled 평가의 항목도 잠긴다")
    func cancelledAssessmentLocksItems() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, items: [itemDraft()])
        ra.status = .cancelled
        try ctx.save()
        #expect(throws: AssessmentItemError.assessmentNotEditable) {
            try AssessmentItemEditing.add(to: ra, task: "추가", hazard: "위험",
                                          likelihood: 1, severity: 1, riskLevel: .low,
                                          at: when, context: ctx)
        }
    }

    @Test("편집 가능 상태 판정은 planned/inProgress 만 참이다")
    func editabilityRule() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        #expect(AssessmentItemEditing.allowsItemEditing(ra))
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        #expect(AssessmentItemEditing.allowsItemEditing(ra))
        ra.status = .cancelled
        #expect(!AssessmentItemEditing.allowsItemEditing(ra))
    }

    // MARK: - update (위험 입력 변경 → 기준확인 무효화)

    @Test("inProgress 에서 위험 입력을 바꾸면 기준확인 3필드가 무효화된다")
    func riskChangeResetsConfirmation() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx, items: [itemDraft(l: 1, s: 1, level: .low)])
        let item = try #require(ra.items?.first)
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        #expect(item.criteriaDecision == .withinThreshold)
        #expect(item.decisionConfirmedBy == "홍길동")

        try AssessmentItemEditing.update(item, in: ra, task: "굴착", hazard: "붕괴",
                                         likelihood: 3, severity: 3, riskLevel: .high,
                                         at: when, context: ctx)

        #expect(item.riskLevel == .high)
        #expect(item.criteriaDecision == nil)          // 무효화
        #expect(item.decisionConfirmedAt == nil)
        #expect(item.decisionConfirmedBy == nil)
    }

    @Test("위험 입력을 그대로 두고 설명만 고치면 기준확인은 유지된다")
    func textOnlyEditKeepsConfirmation() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx, items: [itemDraft(l: 1, s: 1, level: .low)])
        let item = try #require(ra.items?.first)
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")

        try AssessmentItemEditing.update(item, in: ra, task: "굴착(수정)", hazard: "붕괴",
                                         currentControls: "흙막이 보강",
                                         likelihood: 1, severity: 1, riskLevel: .low,
                                         at: when, context: ctx)

        #expect(item.taskDescription == "굴착(수정)")
        #expect(item.currentControls == "흙막이 보강")
        #expect(item.criteriaDecision == .withinThreshold)   // 유지
        #expect(item.decisionConfirmedBy == "홍길동")
    }

    // MARK: - 소유권

    @Test("다른 평가의 항목은 수정·삭제할 수 없다")
    func rejectsItemFromAnotherAssessment() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, items: [itemDraft()])
        let other = try plannedAssessment(in: ctx, items: [itemDraft(task: "타평가")])
        let foreign = try #require(other.items?.first)

        #expect(throws: AssessmentItemError.itemNotInAssessment) {
            try AssessmentItemEditing.update(foreign, in: ra, task: "침입", hazard: "붕괴",
                                             likelihood: 1, severity: 1, riskLevel: .low,
                                             at: when, context: ctx)
        }
        #expect(throws: AssessmentItemError.itemNotInAssessment) {
            try AssessmentItemEditing.remove(foreign, in: ra, at: when, context: ctx)
        }
        #expect(foreign.taskDescription == "타평가")
    }

    // MARK: - remove

    @Test("항목을 삭제하면 그 항목의 개선조치도 함께 사라지고 형제는 보존된다")
    func removesItemAndItsActions() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, items: [
            AssessmentDraft.ItemDraft(taskDescription: "굴착", hazardDescription: "붕괴",
                                      likelihood: 1, severity: 1, riskLevel: .low,
                                      measure: "흙막이"),
            itemDraft(task: "운반", hazard: "협착"),
        ])
        let target = try #require(ra.items?.first { $0.taskDescription == "굴착" })
        #expect((target.correctiveActions ?? []).count == 1)

        try AssessmentItemEditing.remove(target, in: ra, at: when, context: ctx)

        #expect((ra.items ?? []).count == 1)
        #expect(ra.items?.first?.taskDescription == "운반")
        #expect(try ctx.fetch(FetchDescriptor<CorrectiveAction>()).isEmpty)
    }

    // MARK: - commit 실패 원복

    @Test("항목 수정이 commit 에 실패하면 모든 필드가 원복된다")
    func failedUpdateRestoresEveryField() throws {
        let ctx = try makeContext()
        let hazardId = UUID()
        let ra = try plannedAssessment(in: ctx, items: [
            AssessmentDraft.ItemDraft(taskDescription: "굴착", hazardDescription: "붕괴",
                                      currentControls: "흙막이", likelihood: 1, severity: 1,
                                      riskLevel: .low, linkedHazardId: hazardId),
        ])
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        let item = try #require(ra.items?.first)
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        try ctx.save()
        let priorUpdatedAt = ra.updatedAt

        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try AssessmentItemEditing.update(item, in: ra, task: "바뀐작업", hazard: "바뀐위험",
                                             currentControls: "바뀐조치",
                                             likelihood: 3, severity: 3, riskLevel: .high,
                                             linkedHazardId: nil,
                                             at: when.addingTimeInterval(60),
                                             context: ctx, commit: { throw Boom() })
        }

        // 모든 필드가 편집 전 상태로 — 기준확인 3필드까지.
        #expect(item.taskDescription == "굴착")
        #expect(item.hazardDescription == "붕괴")
        #expect(item.currentControls == "흙막이")
        #expect(item.linkedHazardId == hazardId)
        #expect(item.likelihood == 1)
        #expect(item.severity == 1)
        #expect(item.riskLevel == .low)
        #expect(item.criteriaDecision == .withinThreshold)
        #expect(item.decisionConfirmedBy == "홍길동")
        #expect(ra.updatedAt == priorUpdatedAt)
    }

    @Test("항목 삭제가 commit 에 실패하면 항목이 되살아난다")
    func failedRemoveRestoresItem() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, items: [itemDraft(), itemDraft(task: "운반", hazard: "협착")])
        let target = try #require(ra.items?.first { $0.taskDescription == "굴착" })
        let priorUpdatedAt = ra.updatedAt

        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try AssessmentItemEditing.remove(target, in: ra, at: when.addingTimeInterval(60),
                                             context: ctx, commit: { throw Boom() })
        }

        #expect((ra.items ?? []).count == 2)
        #expect((ra.items ?? []).contains { $0.taskDescription == "굴착" })
        #expect(ra.updatedAt == priorUpdatedAt)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentItem>()).count == 2)
    }

    @Test("손상된 기준으로는 항목을 평가·저장하지 않는다 (fail-closed)")
    func corruptCriteriaRefusesItemWrites() throws {
        let ctx = try makeContext()
        let ra = try startedAssessment(in: ctx, items: [itemDraft()])
        // 잠긴 기준의 매트릭스를 못 읽게 만든다 (CloudKit 손상 레코드 재현).
        ra.criteria?.matrixData = Data("{ 손상".utf8)
        try ctx.save()

        #expect(throws: AssessmentItemError.criteriaUnreadable) {
            try AssessmentItemEditing.add(to: ra, task: "추가", hazard: "위험",
                                          likelihood: 1, severity: 1, at: when, context: ctx)
        }
        #expect((ra.items ?? []).count == 1)   // 기본 매트릭스로 조용히 대체하지 않는다
    }

    @Test("항목 추가가 commit 에 실패하면 store 와 메모리 어디에도 남지 않는다")
    func failedAddLeavesNoPhantomItem() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, items: [itemDraft()])
        let priorUpdatedAt = ra.updatedAt

        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try AssessmentItemEditing.add(to: ra, task: "유령", hazard: "유령위험",
                                          likelihood: 1, severity: 1, riskLevel: .low,
                                          at: when.addingTimeInterval(60),
                                          context: ctx, commit: { throw Boom() })
        }

        #expect((ra.items ?? []).count == 1)
        #expect(!(ra.items ?? []).contains { $0.taskDescription == "유령" })
        #expect(ra.updatedAt == priorUpdatedAt)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentItem>()).count == 1)
    }
}
