import Foundation
import SwiftData

/// The ONE way a `SharingEvent` comes into existence (WO LEGAL-2d §2) — the `AssessmentStart` /
/// `CorrectiveActionEditing` pattern applied to 공유 기록: guard fail-closed, build the versioned
/// snapshot, insert, and persist with a store+memory restore if the commit fails.
///
/// The interface is deliberately ONE operation. There is no `update` and no `remove`: a 공유 사실은
/// 일어난 뒤에 고쳐 쓸 수 있는 것이 아니다(SCHEMA_V3 §7 "SharingEvent=생성 즉시" 잠금). Correcting a
/// mis-recorded share means recording the later, correct share — the history keeps both, which is
/// exactly what 여러 실제 공유 이벤트 허용 requires.
public enum SharingEventRecording {

    /// Records that the user shared this assessment.
    ///
    /// - `.pre` is allowed only while the assessment is `.planned` and only when it has a
    ///   `scheduledAt` — 사전 공유 = 일정 공유이므로 공유할 일정이 없으면 기록할 것도 없다.
    /// - `.post` is allowed only once the assessment is `.finalized` — 사후 공유 범위는 확정된
    ///   유해위험요인·결정·개선대책·이행 결과다(LEGAL_SOURCE_TABLE A.2).
    /// - `target`/`ownerName` must be non-blank, and the snapshot is always Core-generated, so a
    ///   business-empty record can never be stored.
    ///
    /// The app records the user's statement that they shared; it never verifies actual delivery.
    @discardableResult
    public static func record(
        phase: SharingPhase,
        method: SharingMethod,
        in assessment: RiskAssessment,
        target: String,
        ownerName: String,
        at date: Date,
        context: ModelContext
    ) throws -> SharingEvent {
        try record(phase: phase, method: method, in: assessment, target: target,
                   ownerName: ownerName, at: date, context: context,
                   commit: { try context.save() })
    }

    /// Testing seam for the commit step (same rationale as `AssessmentStart`/`CorrectiveActionEditing`:
    /// these unique-free CloudKit models can't be made to throw a catchable `save()`). Not public.
    @discardableResult
    static func record(
        phase: SharingPhase,
        method: SharingMethod,
        in assessment: RiskAssessment,
        target: String,
        ownerName: String,
        at date: Date,
        context: ModelContext,
        commit: () throws -> Void
    ) throws -> SharingEvent {
        guard !target.sw_isBlank else { throw SharingRecordError.emptyTarget }
        guard !ownerName.sw_isBlank else { throw SharingRecordError.emptyOwner }
        try requirePhaseAllowed(phase, in: assessment)

        // Value copy at THIS instant — later edits to the assessment never reach this JSON.
        // `makeSnapshot` also enforces the 사전-공유 일정 필수 rule (missingSchedule).
        let snapshot = try SharingEventPolicy.makeSnapshot(phase: phase, for: assessment)
        guard let json = try? snapshot.encoded(), !json.isEmpty else {
            throw SharingRecordError.snapshotFailed
        }

        let priorUpdatedAt = assessment.updatedAt
        let event = SharingEvent(phase: phase, method: method, sharedAt: date,
                                 target: target, contentSnapshot: json, ownerName: ownerName)
        // 저장 직전 같은 완전성 계약으로 재확인 — 생성 관문과 `SharingEventPolicy.isComplete` 가 서로
        // 어긋날 수 없게 묶는다(빈 모델 영속 차단, SCHEMA_V3 §4.1).
        try event.validate()
        context.insert(event)
        event.riskAssessment = assessment
        appendInPlace(event, to: assessment)
        assessment.updatedAt = date

        do {
            try commit()
        } catch {
            context.rollback()
            // `rollback()` reverts the STORE but leaves the in-memory relationship dirty, and
            // SwiftData re-syncs `assessment.sharingEvents` from the still-set inverse — detach the
            // inverse first, then remove in place (the `CorrectiveActionEditing.add` pattern).
            event.riskAssessment = nil
            assessment.sharingEvents?.removeAll { $0 === event }
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
        return event
    }

    /// 사전은 planned, 사후는 finalized — 그 외 상태는 어떤 시점도 기록하지 않는다.
    private static func requirePhaseAllowed(_ phase: SharingPhase, in assessment: RiskAssessment) throws {
        let allowed: AssessmentStatus = (phase == .pre) ? .planned : .finalized
        guard assessment.status == allowed else { throw SharingRecordError.phaseNotAllowed }
    }

    /// In-place append that tolerates SwiftData's inverse auto-sync (never duplicates the event).
    private static func appendInPlace(_ event: SharingEvent, to assessment: RiskAssessment) {
        if assessment.sharingEvents == nil { assessment.sharingEvents = [] }
        if !(assessment.sharingEvents ?? []).contains(where: { $0 === event }) {
            assessment.sharingEvents?.append(event)
        }
    }
}
