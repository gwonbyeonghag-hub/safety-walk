import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-TBM-1 §2.4 — 참석자 추가. draft/conducted 에서만 가능(finalized·cancelled 는 잠금),
// 이름 필수, 공유 enum(ParticipantRole·ConfirmationMethod)만 사용, 선택 서명, 실패 시 원복.
@Suite("BriefingParticipantEditing — 참석자 추가 (TBM-1)")
struct BriefingParticipantEditingTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)

    private func draftBriefing(in ctx: ModelContext) throws -> SafetyBriefing {
        try BriefingAuthoring.create(BriefingDraft(siteId: UUID(), siteName: "1공장"), in: ctx)
    }

    @Test("draft 에 참석자를 추가할 수 있다")
    func addsParticipantToDraft() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)

        let participant = try BriefingParticipantEditing.add(
            to: briefing, name: "김근로", role: .worker,
            confirmationMethod: .selfConfirm, confirmedAt: when, at: when, context: ctx)

        #expect(participant.name == "김근로")
        #expect(participant.role == .worker)
        #expect(participant.confirmationMethod == .selfConfirm)
        #expect(briefing.participants?.count == 1)
        #expect(try ctx.fetch(FetchDescriptor<BriefingParticipant>()).count == 1)
    }

    @Test("conducted 에도 참석자를 추가할 수 있다")
    func addsParticipantToConducted() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "전달", now: when, in: ctx)

        try BriefingParticipantEditing.add(to: briefing, name: "이근로", role: .workerRep,
                                           at: when, context: ctx)

        #expect(briefing.participants?.count == 1)
    }

    @Test("선택 서명을 함께 기록할 수 있다")
    func addsParticipantWithSignature() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        let sig = Data([0x01, 0x02, 0x03])

        let participant = try BriefingParticipantEditing.add(
            to: briefing, name: "박근로", role: .worker,
            confirmationMethod: .signature, confirmedAt: when,
            signatureData: sig, signedAt: when, at: when, context: ctx)

        #expect(participant.signatureData == sig)
        #expect(participant.signedAt == when)
    }

    @Test("finalized 브리핑은 참석자를 잠근다")
    func rejectsAddOnFinalized() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        try BriefingLifecycle.conduct(briefing, briefingContent: "전달", now: when, in: ctx)
        try BriefingLifecycle.finalize(briefing, now: when.addingTimeInterval(60), in: ctx)

        #expect(throws: BriefingParticipantError.briefingNotEditable) {
            try BriefingParticipantEditing.add(to: briefing, name: "최근로", role: .worker,
                                               at: when, context: ctx)
        }
        #expect(briefing.participants?.isEmpty != false)
    }

    @Test("cancelled 브리핑은 참석자를 잠근다")
    func rejectsAddOnCancelled() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        try BriefingLifecycle.cancel(briefing, reason: "취소", now: when, in: ctx)

        #expect(throws: BriefingParticipantError.briefingNotEditable) {
            try BriefingParticipantEditing.add(to: briefing, name: "최근로", role: .worker,
                                               at: when, context: ctx)
        }
    }

    @Test("이름이 비어 있으면 거부된다")
    func rejectsBlankName() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        #expect(throws: BriefingParticipantError.emptyName) {
            try BriefingParticipantEditing.add(to: briefing, name: "  ", role: .worker,
                                               at: when, context: ctx)
        }
        #expect(briefing.participants?.isEmpty != false)
    }

    @Test("commit 이 실패하면 store·메모리 어디에도 남지 않는다")
    func failedAddLeavesNoGhost() throws {
        let ctx = try makeContext()
        let briefing = try draftBriefing(in: ctx)
        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try BriefingParticipantEditing.add(to: briefing, name: "김근로", role: .worker,
                                               employeeId: nil, affiliation: nil, jobTitle: nil,
                                               confirmationMethod: nil, confirmedAt: nil,
                                               signatureData: nil, signedAt: nil,
                                               at: when, context: ctx, commit: { throw Boom() })
        }
        #expect(briefing.participants?.isEmpty != false)
        #expect(try ctx.fetch(FetchDescriptor<BriefingParticipant>()).isEmpty)
    }
}
