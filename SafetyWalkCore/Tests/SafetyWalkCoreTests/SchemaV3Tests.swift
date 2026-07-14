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
        let item = RiskAssessmentItem(taskDescription: "용접", riskLevel: .high,
                                      criteriaDecision: .exceedsThreshold)
        item.riskAssessment = ra
        ctx.insert(item)
        let participant = RiskAssessmentParticipant(name: "김근로", role: .worker)
        participant.riskAssessment = ra
        ctx.insert(participant)
        let action = CorrectiveAction(item: item, measure: "국소배기 설치")
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
        #expect(throws: Never.self) {
            try SharingEvent(phase: .pre, method: .education, sharedAt: Date()).validate()
        }
        #expect(throws: Never.self) {
            try SafetyBriefing(siteId: UUID(), siteName: "현장").validate()
        }
    }
}

@Suite("SchemaV3 — §7 불변식")
struct SchemaV3InvariantTests {

    /// isRequired is derived from the parent item's 초과 여부 — never stored (교정 #2).
    @Test func correctiveActionIsRequiredDerivesFromDecision() {
        let exceed = RiskAssessmentItem(riskLevel: .high, criteriaDecision: .exceedsThreshold)
        #expect(CorrectiveAction(item: exceed).isRequired == true)
        let within = RiskAssessmentItem(riskLevel: .low, criteriaDecision: .withinThreshold)
        #expect(CorrectiveAction(item: within).isRequired == false)
        let unassessed = RiskAssessmentItem(riskLevel: .high)   // criteriaDecision nil = 미평가
        #expect(CorrectiveAction(item: unassessed).isRequired == false)
    }

    /// 효과확인은 result·confirmedBy·effectivenessConfirmedAt 를 한 번에 갱신 — 부분 갱신 없음.
    @Test func effectivenessConfirmUpdatesAllThreeFieldsAtomically() {
        let item = RiskAssessmentItem(riskLevel: .high, criteriaDecision: .exceedsThreshold)
        let action = CorrectiveAction(item: item, measure: "가드 설치")
        #expect(action.isEffectivenessConfirmed == false)
        #expect(action.effectivenessResult == nil)
        #expect(action.confirmedBy == nil)
        #expect(action.effectivenessConfirmedAt == nil)

        let when = Date()
        action.confirmEffectiveness(result: .effective, by: "이관리", at: when)
        #expect(action.effectivenessResult == .effective)
        #expect(action.confirmedBy == "이관리")
        #expect(action.effectivenessConfirmedAt == when)
        #expect(action.isEffectivenessConfirmed == true)
    }

    /// nil=미평가: an item is only 평가완료 when BOTH 위험도 and 초과여부 결정이 있다 (§7).
    @Test func itemIsAssessedRequiresBothLevelAndDecision() {
        #expect(RiskAssessmentItem(riskLevel: .high, criteriaDecision: .exceedsThreshold).isAssessed)
        #expect(!RiskAssessmentItem(riskLevel: .high).isAssessed)                    // 결정 미평가
        #expect(!RiskAssessmentItem(criteriaDecision: .withinThreshold).isAssessed)  // 위험도 미평가
        #expect(!RiskAssessmentItem().isAssessed)                                    // 둘 다 미평가
    }
}
