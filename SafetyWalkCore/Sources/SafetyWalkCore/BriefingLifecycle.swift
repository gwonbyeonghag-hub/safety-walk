import Foundation
import SwiftData

/// Why a 브리핑 수명주기 전환이 거부됐는지 (WO LEGAL-TBM-1 §2.2). 영속 오류는 store·메모리 원복
/// 후 원래 오류로 재전파된다.
public enum BriefingLifecycleError: Error, Equatable {
    case notDraft                    // conduct: draft 만 시작 가능 (재진행 금지)
    case notConducted                // finalize: conducted 만 확정 가능
    case notCancellable              // cancel: draft/conducted 만 취소 가능 — finalized 는 종결된 기록
    case emptyBriefingContent        // conduct: 전달내용 없이 시작 불가
    case sourceAssessmentRequired    // briefing.assessmentId 가 있는데 sourceAssessment 를 안 줌
    case sourceAssessmentMismatch    // 준 sourceAssessment.id 가 briefing.assessmentId 와 다름 (또는 미연결인데 줌)
    case emptyCancellationReason     // cancel: 취소 사유 필수
}

/// TBM 수명주기 전환 — conduct(draft→conducted) / finalize(conducted→finalized) /
/// cancel(draft·conducted→cancelled) (SCHEMA_V3 §7, TBM_0_ARCH §5). 각각 `AssessmentStart`/
/// `AssessmentFinalization` 과 같은 형태의 **단일 원자 연산**이다: 검증 → 필드 전환(+conduct 는
/// 위험 스냅샷 삽입) → commit, 실패 시 store·메모리 원복.
///
/// **잠금 시점** (TBM_0_ARCH §5): `conducted` 는 전달내용(`briefingContent`)·위험 스냅샷
/// (`riskSnapshots`)을 잠근다 — 참석 확인은 `finalized` 전까지 계속 가능
/// (`BriefingParticipantEditing.allowsParticipantEditing` 참고). `finalized` 는 참석자·서명까지
/// 모두 잠근다.
public enum BriefingLifecycle {

    // MARK: - conduct (draft → conducted)

    /// `briefing` 을 시작한다: 전달내용을 기록하고, 연결된 평가(있으면)의 항목을 값 스냅샷으로
    /// 복사한 뒤 `conductedAt`/`updatedAt` 을 찍고 `.conducted` 로 전환한다.
    ///
    /// `briefing.assessmentId` 가 설정돼 있으면 그 평가와 **일치하는** `sourceAssessment` 를
    /// 반드시 받아야 한다(Core 가 UUID 로 직접 조회하지 않는다 — 다른 원자 연산과 같은 관례).
    /// 미연결(`assessmentId == nil`, standalone Toolbox Talk)이면 `sourceAssessment` 는 반드시
    /// `nil` 이어야 하고, 위험 스냅샷은 빈 배열로 시작한다.
    @discardableResult
    public static func conduct(
        _ briefing: SafetyBriefing,
        briefingContent: String,
        sourceAssessment: RiskAssessment? = nil,
        now: Date,
        in context: ModelContext
    ) throws -> SafetyBriefing {
        try conduct(briefing, briefingContent: briefingContent, sourceAssessment: sourceAssessment,
                    now: now, in: context, commit: { try context.save() })
    }

    /// Testing seam for the commit step (같은 이유: unique 없는 CloudKit 모델은 `save()` 를 catch
    /// 가능한 실패로 만들 수 없다). Not public.
    static func conduct(
        _ briefing: SafetyBriefing,
        briefingContent: String,
        sourceAssessment: RiskAssessment?,
        now: Date,
        in context: ModelContext,
        commit: () throws -> Void
    ) throws -> SafetyBriefing {
        guard briefing.status == .draft else { throw BriefingLifecycleError.notDraft }
        guard !briefingContent.sw_isBlank else { throw BriefingLifecycleError.emptyBriefingContent }

        let snapshots: [BriefingRiskItemSnapshot]
        if let assessmentId = briefing.assessmentId {
            guard let sourceAssessment else { throw BriefingLifecycleError.sourceAssessmentRequired }
            guard sourceAssessment.id == assessmentId else { throw BriefingLifecycleError.sourceAssessmentMismatch }
            let items = (sourceAssessment.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
            snapshots = try items.map { try makeSnapshot(from: $0, sourceAssessmentId: sourceAssessment.id) }
        } else {
            guard sourceAssessment == nil else { throw BriefingLifecycleError.sourceAssessmentMismatch }
            snapshots = []
        }

        let priorRiskSnapshots = briefing.riskSnapshots ?? []
        let priorContent = briefing.briefingContent
        let priorStatus = briefing.status
        let priorConductedAt = briefing.conductedAt
        let priorUpdatedAt = briefing.updatedAt

        briefing.briefingContent = briefingContent.trimmed
        briefing.status = .conducted
        briefing.conductedAt = now
        briefing.updatedAt = now
        for snapshot in snapshots {
            context.insert(snapshot)
            snapshot.briefing = briefing
        }
        briefing.riskSnapshots = snapshots

        do {
            try commit()
        } catch {
            // rollback 은 store 만 되돌린다 — 메모리 관계가 살아 있으면 SwiftData 가 다시 동기화하므로
            // inverse 를 먼저 끊고 삽입한 스냅샷을 지운다(`AssessmentAuthoring.create` 패턴).
            for snapshot in snapshots {
                snapshot.briefing = nil
                context.delete(snapshot)
            }
            briefing.riskSnapshots = priorRiskSnapshots
            briefing.briefingContent = priorContent
            briefing.status = priorStatus
            briefing.conductedAt = priorConductedAt
            briefing.updatedAt = priorUpdatedAt
            context.rollback()
            throw error
        }
        return briefing
    }

    /// 항목 하나의 값 스냅샷 — 정규 값(작업·유해위험요인·riskLevel?·likelihood/severity·현재조치)을
    /// 그대로 복사하고, 1:N 개선조치는 `BriefingControlMeasuresSnapshot` 으로 인코딩한다.
    /// `CorrectiveActionPolicy.sortedCorrectiveActions` 로 결정적 순서를 쓴다(CloudKit 은 to-many
    /// 순서를 보장하지 않는다).
    private static func makeSnapshot(
        from item: RiskAssessmentItem,
        sourceAssessmentId: UUID
    ) throws -> BriefingRiskItemSnapshot {
        let actions = CorrectiveActionPolicy.sortedCorrectiveActions(item).map {
            BriefingControlMeasureSnapshot(
                actionId: $0.id, measure: $0.measure, responsibleName: $0.responsibleName,
                dueDate: $0.dueDate, status: $0.status.rawValue, postRiskLevel: $0.postRiskLevel?.rawValue)
        }
        let data = try BriefingControlMeasuresSnapshot(measures: actions).encoded()
        return BriefingRiskItemSnapshot(
            sourceAssessmentId: sourceAssessmentId,
            sourceItemId: item.id,
            taskDescription: item.taskDescription,
            hazardDescription: item.hazardDescription,
            currentControls: item.currentControls ?? "",
            riskLevel: item.riskLevel,
            likelihood: item.likelihood,
            severity: item.severity,
            controlMeasuresSnapshot: data,
            controlMeasuresFormatVersion: BriefingControlMeasuresSnapshot.currentFormatVersion)
    }

    // MARK: - finalize (conducted → finalized)

    @discardableResult
    public static func finalize(
        _ briefing: SafetyBriefing,
        now: Date,
        in context: ModelContext
    ) throws -> SafetyBriefing {
        try finalize(briefing, now: now, in: context, commit: { try context.save() })
    }

    static func finalize(
        _ briefing: SafetyBriefing,
        now: Date,
        in context: ModelContext,
        commit: () throws -> Void
    ) throws -> SafetyBriefing {
        guard briefing.status == .conducted else { throw BriefingLifecycleError.notConducted }

        let priorStatus = briefing.status
        let priorFinalizedAt = briefing.finalizedAt
        let priorUpdatedAt = briefing.updatedAt
        briefing.status = .finalized
        briefing.finalizedAt = now
        briefing.updatedAt = now

        do {
            try commit()
        } catch {
            context.rollback()
            briefing.status = priorStatus
            briefing.finalizedAt = priorFinalizedAt
            briefing.updatedAt = priorUpdatedAt
            throw error
        }
        return briefing
    }

    // MARK: - cancel (draft/conducted → cancelled)

    /// `finalized` 는 취소 대상에서 제외한다 — 참석·서명까지 잠긴 종결 기록이라, 잘못 기록됐다면
    /// 정정(supersede, TBM_0_ARCH §7 — 이번 WO 범위 밖)이 맞는 경로다. `cancelled` 재취소도 거부.
    @discardableResult
    public static func cancel(
        _ briefing: SafetyBriefing,
        reason: String,
        now: Date,
        in context: ModelContext
    ) throws -> SafetyBriefing {
        try cancel(briefing, reason: reason, now: now, in: context, commit: { try context.save() })
    }

    static func cancel(
        _ briefing: SafetyBriefing,
        reason: String,
        now: Date,
        in context: ModelContext,
        commit: () throws -> Void
    ) throws -> SafetyBriefing {
        guard briefing.status == .draft || briefing.status == .conducted else {
            throw BriefingLifecycleError.notCancellable
        }
        guard !reason.sw_isBlank else { throw BriefingLifecycleError.emptyCancellationReason }

        let priorStatus = briefing.status
        let priorCancelledAt = briefing.cancelledAt
        let priorReason = briefing.cancellationReason
        let priorUpdatedAt = briefing.updatedAt
        briefing.status = .cancelled
        briefing.cancelledAt = now
        briefing.cancellationReason = reason.trimmed
        briefing.updatedAt = now

        do {
            try commit()
        } catch {
            context.rollback()
            briefing.status = priorStatus
            briefing.cancelledAt = priorCancelledAt
            briefing.cancellationReason = priorReason
            briefing.updatedAt = priorUpdatedAt
            throw error
        }
        return briefing
    }
}
