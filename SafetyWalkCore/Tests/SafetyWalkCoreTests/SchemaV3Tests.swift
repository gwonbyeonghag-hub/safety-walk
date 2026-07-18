import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// SCHEMA_V3: proves the 15-model baseline registers, builds (all relationships resolve their
// inverse), round-trips with cascade deletes, and that the §4.1 constructor-contract validation
// + §7 invariants (nil=미기록, isRequired 파생, 효과확인 원자 갱신) hold.

@Suite("SchemaV3 — 15-model baseline")
struct SchemaV3RegistrationTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test func registersAll15Models() {
        #expect(SchemaV3.models.count == 15)
        #expect(SchemaV3.versionIdentifier == Schema.Version(3, 0, 0))
    }

    /// Building the container resolves every `@Relationship(inverse:)` — a missing/mismatched
    /// inverse fails here, which is the CloudKit constraint the schema must satisfy.
    @Test func containerBuildsAndResolvesInverses() throws {
        _ = try makeContainer()
    }

    /// Full aggregate round-trips; cascade delete of the root removes its owned children
    /// (items/participants and the item's corrective actions), while UUID-linked records survive.
    @Test func assessmentPersistsWithChildrenAndCascades() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let ra = RiskAssessment(kind: .regular, method: .threeLevel,
                                siteId: UUID(), siteName: "가나 현장")
        ctx.insert(ra)
        let item = RiskAssessmentItem(taskDescription: "용접", riskLevel: .high)
        item.criteriaDecision = .exceedsThreshold   // @testable: internal setter for a cascade fixture
        item.riskAssessment = ra
        ctx.insert(item)
        let participant = RiskAssessmentParticipant(name: "김근로", role: .worker)
        participant.riskAssessment = ra
        ctx.insert(participant)
        let action = try CorrectiveActionPolicy.makeDraft(item: item, measure: "국소배기 설치")
        ctx.insert(action)
        try ctx.save()

        let raId = ra.id
        let fetched = try #require(
            try ctx.fetch(FetchDescriptor<RiskAssessment>()).first { $0.id == raId })
        #expect(fetched.items?.count == 1)
        #expect(fetched.participants?.count == 1)
        #expect(fetched.items?.first?.correctiveActions?.count == 1)

        ctx.delete(fetched)
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentItem>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<RiskAssessmentParticipant>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<CorrectiveAction>()).isEmpty)
    }
}

@Suite("SchemaV3 — §4.1 생성자 계약 validation")
struct SchemaV3ValidationTests {

    @Test func participantRequiresNonBlankName() {
        #expect(throws: ModelValidationError.emptyName) {
            try RiskAssessmentParticipant(name: "   ", role: .worker).validate()
        }
        #expect(throws: Never.self) {
            try RiskAssessmentParticipant(name: "김근로", role: .workerRep).validate()
        }
    }

    @Test func briefingParticipantRequiresNonBlankName() {
        #expect(throws: ModelValidationError.emptyName) {
            try BriefingParticipant(name: "", role: .worker).validate()
        }
        #expect(throws: Never.self) {
            try BriefingParticipant(name: "박근로", role: .worker).validate()
        }
    }

    @Test func assessmentRequiresNonBlankSiteName() {
        #expect(throws: ModelValidationError.emptySiteName) {
            try RiskAssessment(kind: .regular, method: .threeLevel,
                               siteId: UUID(), siteName: " ").validate()
        }
        #expect(throws: Never.self) {
            try RiskAssessment(kind: .regular, method: .threeLevel,
                               siteId: UUID(), siteName: "현장").validate()
        }
    }

    @Test func programAndSharingEventValidate() {
        #expect(throws: Never.self) {
            try RiskAssessmentProgram(siteId: UUID(), siteName: "현장", jurisdiction: .kr).validate()
        }
        // WO LEGAL-2d: the data init is Core-internal (외부 생성은 SharingEventRecording.record 만) —
        // reachable here only via @testable. 생성 계약이 target·contentSnapshot·ownerName까지 요구하므로
        // 업무상 빈 공유 기록은 애초에 구성되지 않는다.
        #expect(throws: Never.self) {
            try SharingEvent(phase: .pre, method: .education, sharedAt: Date(),
                             target: "전 근로자", contentSnapshot: "{}", ownerName: "홍길동").validate()
        }
        #expect(throws: Never.self) {
            try SafetyBriefing(siteId: UUID(), siteName: "현장").validate()
        }
    }
}

@Suite("SchemaV3 — §7 불변식")
struct SchemaV3InvariantTests {

    /// isRequired is derived from the parent item's 초과 여부 — never stored (교정 #2).
    @Test func correctiveActionIsRequiredDerivesFromDecision() throws {
        let exceed = RiskAssessmentItem(riskLevel: .high); exceed.criteriaDecision = .exceedsThreshold
        #expect(CorrectiveActionPolicy.isRequired(try CorrectiveActionPolicy.makeDraft(item: exceed, measure: "조치")) == true)
        let within = RiskAssessmentItem(riskLevel: .low); within.criteriaDecision = .withinThreshold
        #expect(CorrectiveActionPolicy.isRequired(try CorrectiveActionPolicy.makeDraft(item: within, measure: "조치")) == false)
        let unassessed = RiskAssessmentItem(riskLevel: .high)   // criteriaDecision nil = 미평가
        #expect(CorrectiveActionPolicy.isRequired(try CorrectiveActionPolicy.makeDraft(item: unassessed, measure: "조치")) == false)
    }

    /// 효과확인은 result·confirmedBy·effectivenessConfirmedAt 를 한 번에 갱신 — 부분 갱신 없음.
    @Test func effectivenessConfirmUpdatesAllThreeFieldsAtomically() throws {
        let item = RiskAssessmentItem(riskLevel: .high)
        let action = try CorrectiveActionPolicy.makeDraft(item: item, measure: "가드 설치")
        #expect(CorrectiveActionPolicy.isEffectivenessConfirmed(action) == false)
        #expect(action.effectivenessResult == nil)
        #expect(action.confirmedBy == nil)
        #expect(action.effectivenessConfirmedAt == nil)

        let when = Date()
        CorrectiveActionPolicy.applyEffectiveness(to: action, result: .effective, by: "이관리", at: when)
        #expect(action.effectivenessResult == .effective)
        #expect(action.confirmedBy == "이관리")
        #expect(action.effectivenessConfirmedAt == when)
        #expect(CorrectiveActionPolicy.isEffectivenessConfirmed(action) == true)
    }

    /// nil=미평가: an item is 평가완료 only with a 위험도 AND a COMPLETE confirmation — decision +
    /// 확인시각 + 비어있지 않은 확인자 (WO LEGAL-2b P2). A bare decision is not enough.
    @Test func itemIsAssessedRequiresLevelAndCompleteConfirmation() {
        // 완전 확정
        let full = RiskAssessmentItem(riskLevel: .high)
        full.criteriaDecision = .exceedsThreshold
        full.decisionConfirmedAt = Date()
        full.decisionConfirmedBy = "홍길동"
        #expect(full.isAssessed)
        // 결정만(확인시각·확인자 없음) → 미평가
        let partial = RiskAssessmentItem(riskLevel: .high); partial.criteriaDecision = .exceedsThreshold
        #expect(!partial.isAssessed)
        // 확인자 공백 → 미평가
        let blank = RiskAssessmentItem(riskLevel: .high)
        blank.criteriaDecision = .exceedsThreshold; blank.decisionConfirmedAt = Date(); blank.decisionConfirmedBy = "  "
        #expect(!blank.isAssessed)
        // 위험도 없음 → 미평가
        let noLevel = RiskAssessmentItem(); noLevel.criteriaDecision = .withinThreshold
        #expect(!noLevel.isAssessed)
        // 둘 다 미평가
        #expect(!RiskAssessmentItem().isAssessed)
    }
}
