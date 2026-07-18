import Foundation
import SwiftData

/// Why a 평가 확정 was refused (WO LEGAL-2d §5). Validation-stage errors; persistence errors
/// propagate as the underlying thrown error after `context.rollback()` + in-memory restore.
public enum AssessmentFinalizeError: Error, Equatable {
    case notInProgress             // inProgress 평가만 확정 가능 (재확정·planned 확정 금지)
    case notReady                  // readiness 전건 미충족 (위험도·결정·필수 개선조치 계획)
    case missingCurrentPreSharing  // KR 관할: 현재 일정과 일치하는 사전 공유 기록 없음
}

/// Finalize-READINESS check **and** the atomic inProgress → finalized transition for a 위험성평가
/// (WO LEGAL-2b §4/§7 + WO LEGAL-2d §5). Keeping both here (Core) lets iOS and macOS gate 확정
/// through one rule instead of each re-deriving it.
public enum AssessmentFinalization {

    /// True only when the assessment is ready to be finalized:
    /// - status is `.inProgress` (planned/finalized/cancelled are never ready),
    /// - a criteria exists, is locked (`lockedAt`), and FULLY decodes — matrix **and** threshold
    ///   (a corrupt snapshot or an out-of-policy threshold is fail-closed → not ready),
    /// - at least one item,
    /// - every item has its risk input AND a CURRENT confirmation: three decision fields present
    ///   and the stored decision still equals the suggestion recomputed from the current input
    ///   (a stale decision after a risk/criteria change makes it not ready),
    /// - every 기준 초과 item has a 개선조치 계획 (≥1 measure-bearing corrective action) — WO LEGAL-2c.
    public static func isReadyToFinalize(_ assessment: RiskAssessment) -> Bool {
        guard assessment.status == .inProgress else { return false }
        guard let stored = assessment.criteria, stored.lockedAt != nil else { return false }
        guard let criteria = try? AcceptabilityCriteria.decode(
            from: stored, usesFrequencySeverity: assessment.method.usesFrequencySeverity)
        else { return false }
        guard let items = assessment.items, !items.isEmpty else { return false }
        for item in items {
            guard item.riskLevel != nil,
                  item.hasCurrentCriteriaDecision(under: criteria),
                  CorrectiveActionPolicy.hasRequiredCorrectiveActionPlan(item)
            else { return false }
        }
        return true
    }

    // MARK: - 확정 (inProgress → finalized) — 원자 연산

    /// Finalizes `assessment`: re-verifies EVERY readiness condition (the predicate is a UI hint;
    /// this is the authority), stamps `finalizedAt`/`updatedAt`, flips `status` to `.finalized`,
    /// and saves — all or nothing.
    ///
    /// Re-verification is not redundant with the button's `isReadyToFinalize`: between the render
    /// and the tap an item's risk can change or a required 개선조치 can be removed, and CloudKit can
    /// deliver a remote edit at any point. The op never trusts the caller's earlier check.
    ///
    /// On any failure the store rolls back AND the in-memory instance is restored, so a held
    /// reference can't read a phantom `.finalized` (WO LEGAL-2d §5 — UI must not dismiss on error).
    public static func finalize(
        _ assessment: RiskAssessment,
        now: Date,
        in context: ModelContext
    ) throws {
        try finalize(assessment, now: now, in: context, commit: { try context.save() })
    }

    /// Testing seam for the commit step (same rationale as `AssessmentStart`). Not public.
    static func finalize(
        _ assessment: RiskAssessment,
        now: Date,
        in context: ModelContext,
        commit: () throws -> Void
    ) throws {
        guard assessment.status == .inProgress else { throw AssessmentFinalizeError.notInProgress }
        guard isReadyToFinalize(assessment) else { throw AssessmentFinalizeError.notReady }
        // KR 관할: 시작 때 확인한 사전 공유를 확정 시점에 다시 검증한다 — 시작 이후 일정이 바뀌었으면
        // 그 사전 공유는 현재 일정과 불일치하므로 게이트가 다시 닫힌다(WO LEGAL-2d §5).
        guard SharingEventPolicy.satisfiesPreSharingGate(assessment) else {
            throw AssessmentFinalizeError.missingCurrentPreSharing
        }

        // Captured so the in-memory assessment can be restored on failure — `context.rollback()`
        // reverts the STORE but leaves the mutated instance dirty. (The prior status is necessarily
        // `.inProgress` after the guard above, so the restore names it directly.)
        let priorFinalizedAt = assessment.finalizedAt
        let priorUpdatedAt = assessment.updatedAt

        assessment.status = .finalized
        assessment.finalizedAt = now
        assessment.updatedAt = now

        do {
            try commit()
        } catch {
            context.rollback()
            assessment.status = .inProgress
            assessment.finalizedAt = priorFinalizedAt
            assessment.updatedAt = priorUpdatedAt
            throw error
        }
    }
}
