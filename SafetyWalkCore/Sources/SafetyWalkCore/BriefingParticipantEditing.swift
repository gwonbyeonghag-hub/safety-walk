import Foundation
import SwiftData

/// 참석자 추가가 거부된 이유 (WO LEGAL-TBM-1 §2.4). 영속 오류는 store·메모리 원복 후 재전파된다.
public enum BriefingParticipantError: Error, Equatable {
    case briefingNotEditable   // finalized/cancelled 는 참석자가 잠긴다
    case emptyName             // 이름 필수
}

/// TBM 참석자 추가의 **단일 원자 연산** (`AssessmentItemEditing.add`/`SharingEventRecording.record`
/// 와 같은 형태) — 이 타입 밖에서 `BriefingParticipant` 를 만들 방법은 없다(init 이 non-public).
public enum BriefingParticipantEditing {

    /// 참석자 편집(추가) 가능 상태 — `draft`·`conducted` 에서만 가능. `finalized` 는 참석·서명까지
    /// 잠기고(TBM_0_ARCH §5), `cancelled` 는 더 이상 진행 중인 브리핑이 아니다.
    public static func allowsParticipantEditing(_ briefing: SafetyBriefing) -> Bool {
        briefing.status == .draft || briefing.status == .conducted
    }

    @discardableResult
    public static func add(
        to briefing: SafetyBriefing,
        name: String,
        role: ParticipantRole,
        employeeId: String? = nil,
        affiliation: String? = nil,
        jobTitle: String? = nil,
        confirmationMethod: ConfirmationMethod? = nil,
        confirmedAt: Date? = nil,
        signatureData: Data? = nil,
        signedAt: Date? = nil,
        at date: Date,
        context: ModelContext
    ) throws -> BriefingParticipant {
        try add(to: briefing, name: name, role: role, employeeId: employeeId, affiliation: affiliation,
                jobTitle: jobTitle, confirmationMethod: confirmationMethod, confirmedAt: confirmedAt,
                signatureData: signatureData, signedAt: signedAt, at: date, context: context,
                commit: { try context.save() })
    }

    /// Testing seam for the commit step. Not public.
    @discardableResult
    static func add(
        to briefing: SafetyBriefing,
        name: String,
        role: ParticipantRole,
        employeeId: String?,
        affiliation: String?,
        jobTitle: String?,
        confirmationMethod: ConfirmationMethod?,
        confirmedAt: Date?,
        signatureData: Data?,
        signedAt: Date?,
        at date: Date,
        context: ModelContext,
        commit: () throws -> Void
    ) throws -> BriefingParticipant {
        guard allowsParticipantEditing(briefing) else { throw BriefingParticipantError.briefingNotEditable }
        guard !name.sw_isBlank else { throw BriefingParticipantError.emptyName }

        let priorParticipants = briefing.participants ?? []
        let priorUpdatedAt = briefing.updatedAt

        let participant = BriefingParticipant(
            name: name.trimmed,
            role: role,
            employeeId: employeeId?.trimmedOrNil,
            affiliation: affiliation?.trimmedOrNil,
            jobTitle: jobTitle?.trimmedOrNil,
            confirmationMethod: confirmationMethod,
            confirmedAt: confirmedAt)
        participant.signatureData = signatureData
        participant.signedAt = signedAt
        context.insert(participant)
        participant.briefing = briefing
        appendInPlace(participant, to: briefing)
        briefing.updatedAt = date

        do {
            try commit()
        } catch {
            participant.briefing = nil
            context.delete(participant)
            briefing.participants = priorParticipants
            briefing.updatedAt = priorUpdatedAt
            context.rollback()
            throw error
        }
        return participant
    }

    /// In-place append that tolerates SwiftData's inverse auto-sync (never duplicates the participant).
    private static func appendInPlace(_ participant: BriefingParticipant, to briefing: SafetyBriefing) {
        if briefing.participants == nil { briefing.participants = [] }
        if !(briefing.participants ?? []).contains(where: { $0 === participant }) {
            briefing.participants?.append(participant)
        }
    }
}
