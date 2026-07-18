import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2c (오너 판단 5차) — 개선조치 생성의 단일 검증 관문.
//
// `CorrectiveAction` @Model 은 순수 데이터 컨테이너(internal 데이터 initializer, 업무 검증 없음)이고,
// 검증은 전부 독립 타입의 public factory `CorrectiveActionPolicy.makeDraft` 가 소유한다. 평가가 아직
// `.planned` 인 최초 작성 경로(ViewModel·Mac SeedData)는 편집용 원자 API `CorrectiveActionEditing.add`
// 를 쓸 수 없으므로(planned 는 편집 불가) 이 factory 가 그 경로의 정식 생성 수단이다.
//
// factory 는 검증된 모델을 **반환만** 한다 — insert/save 는 호출자(또는 `add`)의 책임.

@Suite("CorrectiveActionPolicy.makeDraft — 검증된 생성 관문 (LEGAL-2c 5차)")
struct CorrectiveActionDraftTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeItem(in ctx: ModelContext) -> RiskAssessmentItem {
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium)
        ctx.insert(item)
        return item
    }

    // MARK: - 감소대책(measure) 공백 거부

    @Test func makeDraftRejectsEmptyMeasure() throws {
        let ctx = try makeContext()
        let item = makeItem(in: ctx)
        #expect(throws: CorrectiveActionError.emptyMeasure) {
            try CorrectiveActionPolicy.makeDraft(item: item, measure: "")
        }
    }

    @Test func makeDraftRejectsWhitespaceOnlyMeasure() throws {
        let ctx = try makeContext()
        let item = makeItem(in: ctx)
        #expect(throws: CorrectiveActionError.emptyMeasure) {
            try CorrectiveActionPolicy.makeDraft(item: item, measure: "   \n\t ")
        }
    }

    // MARK: - 최초 상태는 항상 미착수(.notStarted), 완료·효과확인 필드는 비어 있음

    @Test func makeDraftIsAlwaysNotStartedWithEmptyCompletionFields() throws {
        let ctx = try makeContext()
        let item = makeItem(in: ctx)

        let draft = try CorrectiveActionPolicy.makeDraft(
            item: item, measure: "난간 설치", responsibleName: "홍길동", dueDate: when)

        #expect(draft.status == .notStarted)
        #expect(draft.implementedAt == nil)
        #expect(draft.postRiskLevel == nil)
        #expect(draft.effectivenessResult == nil)
        #expect(draft.confirmedBy == nil)
        #expect(draft.effectivenessConfirmedAt == nil)
        #expect(draft.evidencePhotoData == nil)
    }

    @Test func makeDraftCarriesMeasureOwnerAndDueDate() throws {
        let ctx = try makeContext()
        let item = makeItem(in: ctx)

        let draft = try CorrectiveActionPolicy.makeDraft(
            item: item, measure: "국소배기 설치", responsibleName: "김담당", dueDate: when)

        #expect(draft.measure == "국소배기 설치")
        #expect(draft.responsibleName == "김담당")
        #expect(draft.dueDate == when)
        #expect(draft.item === item)
    }

    /// 담당자·기한은 선택 — 생략하면 nil 로 남는다(빈 문자열을 만들지 않는다).
    @Test func makeDraftLeavesOptionalMetadataNil() throws {
        let ctx = try makeContext()
        let item = makeItem(in: ctx)

        let draft = try CorrectiveActionPolicy.makeDraft(item: item, measure: "가드 설치")

        #expect(draft.responsibleName == nil)
        #expect(draft.dueDate == nil)
    }
}
