import Foundation
import SwiftData

/// Why a 공유 기록 was refused (WO LEGAL-2d). Validation-stage errors; persistence errors propagate
/// as the underlying thrown error after `context.rollback()` + in-memory restore.
public enum SharingRecordError: Error, Equatable {
    case emptyTarget         // 공유 대상 공백 — 빈 공유 기록 저장 금지
    case emptyOwner          // 공유 담당자 공백
    case missingSchedule     // 사전 공유인데 평가 일정(scheduledAt) 없음
    case phaseNotAllowed     // 사전은 planned에서만, 사후는 finalized에서만
    case snapshotFailed      // 스냅샷 인코딩 실패 (빈 contentSnapshot 저장 금지)
}

/// WO LEGAL-2d 공유 정책 — an INDEPENDENT type (not a model extension) so `SharingEvent`'s `@Model`
/// body stays a pure data container, exactly as `CorrectiveActionPolicy` does for `CorrectiveAction`.
///
/// It owns three things the rest of the app must not re-derive:
/// 1. **스냅샷 생성** — the single place that turns live models into an immutable versioned value.
/// 2. **최신성(staleness)** — whether a past 공유 기록 still describes the assessment's current state.
///    Derived by re-building the snapshot and comparing, so ANY drift (일정 변경·위험도·결정·조치 변경)
///    is covered by one rule instead of a per-field checklist that can go out of date.
/// 3. **관할 게이트** — which sharing record KR law requires before 시작/확정/종결, and the explicit
///    "관할 미설정" state that must never be reported as 법규 충족.
public enum SharingEventPolicy {

    // MARK: - 스냅샷 생성

    /// Builds the versioned snapshot for `phase` from the assessment's CURRENT state.
    /// - `.pre` carries the 일정 + 평가 문맥 (항목 없음 — 사전 공유는 일정 공유다).
    /// - `.post` additionally value-copies every item and each item's 1:N 개선조치.
    ///
    /// Sorting is deterministic (items by `sortOrder` then `id`; actions by the same `id` order the
    /// screens and reports use) so re-deriving the same state always yields byte-identical JSON.
    public static func makeSnapshot(phase: SharingPhase, for assessment: RiskAssessment) throws -> SharingSnapshot {
        if phase == .pre, assessment.scheduledAt == nil {
            throw SharingRecordError.missingSchedule
        }
        return SharingSnapshot(
            formatVersion: SharingSnapshot.currentFormatVersion,
            phase: phase.rawValue,
            assessmentId: assessment.id,
            siteName: assessment.siteName,
            kind: assessment.kind.rawValue,
            method: assessment.method.rawValue,
            jurisdiction: assessment.jurisdictionSnapshot?.rawValue,
            industryProfile: assessment.industryProfileSnapshot?.rawValue,
            scheduledAt: assessment.scheduledAt,
            items: phase == .post ? snapshotItems(of: assessment) : [])
    }

    /// Convenience for the persisted form — what actually lands in `SharingEvent.contentSnapshot`.
    public static func makeSnapshotJSON(phase: SharingPhase, for assessment: RiskAssessment) throws -> String {
        try makeSnapshot(phase: phase, for: assessment).encoded()
    }

    private static func snapshotItems(of assessment: RiskAssessment) -> [SharingSnapshot.Item] {
        let sorted = (assessment.items ?? []).sorted {
            $0.sortOrder != $1.sortOrder ? $0.sortOrder < $1.sortOrder
                                         : $0.id.uuidString < $1.id.uuidString
        }
        return sorted.map { item in
            SharingSnapshot.Item(
                itemId: item.id,
                sortOrder: item.sortOrder,
                taskDescription: item.taskDescription,
                hazardDescription: item.hazardDescription,
                currentControls: item.currentControls,
                riskLevel: item.riskLevel?.rawValue,
                likelihood: item.likelihood,
                severity: item.severity,
                criteriaDecision: item.criteriaDecision?.rawValue,
                decisionConfirmedAt: item.decisionConfirmedAt,
                decisionConfirmedBy: item.decisionConfirmedBy,
                correctiveActions: CorrectiveActionPolicy.sortedCorrectiveActions(item).map(snapshotAction))
        }
    }

    /// 증거사진(`evidencePhotoData`)은 의도적으로 제외 — 스냅샷은 값 기록이지 바이너리 사본이 아니다.
    private static func snapshotAction(_ action: CorrectiveAction) -> SharingSnapshot.Action {
        SharingSnapshot.Action(
            actionId: action.id,
            measure: action.measure,
            responsibleName: action.responsibleName,
            dueDate: action.dueDate,
            status: action.status.rawValue,
            implementedAt: action.implementedAt,
            postRiskLevel: action.postRiskLevel?.rawValue,
            effectivenessResult: action.effectivenessResult?.rawValue,
            effectivenessConfirmedAt: action.effectivenessConfirmedAt,
            confirmedBy: action.confirmedBy)
    }

    // MARK: - 이력 조회

    /// 공유 이력 — 시간 역순(최근 먼저). CloudKit은 to-many 순서를 보장하지 않으므로 동시각은 `id`로
    /// 안정 정렬해 화면·검증이 늘 같은 순서를 본다.
    public static func sortedEvents(_ assessment: RiskAssessment) -> [SharingEvent] {
        (assessment.sharingEvents ?? []).sorted {
            let l = $0.sharedAt ?? .distantPast
            let r = $1.sharedAt ?? .distantPast
            return l != r ? l > r : $0.id.uuidString < $1.id.uuidString
        }
    }

    /// Reads a stored snapshot back — fail-closed(던진다). 호출부는 현재 데이터로 대체하면 안 된다.
    public static func decodeSnapshot(_ event: SharingEvent) throws -> SharingSnapshot {
        try SharingSnapshot.decode(event.contentSnapshot)
    }

    // MARK: - 최신성(stale) 판정

    /// 이 공유 기록이 평가의 **현재 상태와 더 이상 일치하지 않는가**.
    ///
    /// 필드별 체크리스트 대신 **당시 스냅샷 == 지금 다시 만든 스냅샷** 하나로 판정한다. 스냅샷 인코딩이
    /// 결정적이므로 일정 변경·위험도 변경·결정 변경·개선조치 추가/수정/삭제가 전부 이 한 규칙에 걸린다
    /// (규칙이 늘어도 판정이 낡지 않는다).
    ///
    /// stale 은 삭제가 아니다 — 과거 기록은 그대로 보존되고, 다만 '현재 상태 공유'로 세지 않을 뿐이다.
    /// decode 실패·시점 누락·스냅샷 재생성 실패는 모두 fail-closed 로 stale 취급한다.
    public static func isStale(_ event: SharingEvent, in assessment: RiskAssessment) -> Bool {
        guard let phase = event.phase,
              let recorded = try? decodeSnapshot(event),
              let current = try? makeSnapshot(phase: phase, for: assessment)
        else { return true }
        return recorded != current
    }

    /// 해당 시점의 **현재 유효한** 공유 기록 — 최신 것 중 stale 하지 않은 첫 기록. 없으면 nil.
    public static func currentEvent(phase: SharingPhase, in assessment: RiskAssessment) -> SharingEvent? {
        sortedEvents(assessment).first { $0.phase == phase && !isStale($0, in: assessment) }
    }

    // MARK: - 관할 게이트

    /// 이 평가에 적용할 법적 관할 상태. `unset` 은 "아직 정해지지 않음"이며 **어떤 관할의 충족도 주장하지
    /// 않는다** — 화면은 이를 '관할 미설정'으로 표시해야지 통과/충족으로 보여선 안 된다(WO LEGAL-2d §4).
    public enum JurisdictionState: Equatable, Sendable {
        case kr
        case us
        case unset
    }

    public static func jurisdictionState(_ assessment: RiskAssessment) -> JurisdictionState {
        switch assessment.jurisdictionSnapshot {
        case .kr:  return .kr
        case .us:  return .us
        case nil:  return .unset
        }
    }

    /// KR 전용: 시행규칙 제37조의3 사전(일정) 공유가 시작·확정의 전제인가. US·미설정에는 강제하지 않는다
    /// (앱은 기록 도구이지 판정 도구가 아니며, 다른 관할에 KR 법정 요건을 부과하지 않는다).
    public static func requiresPreSharingGate(_ assessment: RiskAssessment) -> Bool {
        jurisdictionState(assessment) == .kr
    }

    /// KR 전용: 사후(결과) 공유가 종결 파생의 전제인가.
    public static func requiresPostSharingGate(_ assessment: RiskAssessment) -> Bool {
        jurisdictionState(assessment) == .kr
    }

    /// KR 게이트 충족 여부 — 현재 일정과 일치하는 사전 공유가 있는가. 비KR은 항상 true(게이트 없음).
    public static func satisfiesPreSharingGate(_ assessment: RiskAssessment) -> Bool {
        guard requiresPreSharingGate(assessment) else { return true }
        return currentEvent(phase: .pre, in: assessment) != nil
    }

    /// KR 게이트 충족 여부 — 현재 평가·조치 상태와 일치하는 사후 공유가 있는가. 비KR은 항상 true.
    public static func satisfiesPostSharingGate(_ assessment: RiskAssessment) -> Bool {
        guard requiresPostSharingGate(assessment) else { return true }
        return currentEvent(phase: .post, in: assessment) != nil
    }
}
