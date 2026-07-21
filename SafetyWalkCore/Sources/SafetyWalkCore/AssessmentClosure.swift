import Foundation
import SwiftData

/// 종결(closed) 파생 — `closed` 는 저장 상태가 아니라 계산이다(LEGAL_2_ARCH §1.1). WO LEGAL-2c 는
/// finalize 전환을 소유하지 않고 이 파생만 제공한다: finalized 된 평가에서 모든 필수 개선조치의
/// 이행·효과확인이 끝나야 "종결"로 표시할 수 있다. (finalize 버튼/상태 전환은 후속 슬라이스.)
///
/// `ModelContext` 를 받는 이유(WO LEGAL-TBM-4 §2.1·§3): KR 사후 공유 게이트는 이제 `SharingEvent`뿐
/// 아니라 확정 TBM 브리핑도 인정한다. `SafetyBriefing.assessmentId` 는 관계가 아니라 값 UUID라
/// (SCHEMA_V3 동결, 새 관계 추가 불가) 조회에 fetch 가 필요하다 — `UnifiedSharingHistory.entries` 가
/// 이미 쓰는 것과 같은 "Core 안에서 읽기 전용 fetch" 패턴.
public enum AssessmentClosure {

    /// `closed` ⇔
    /// - 평가가 `.finalized`, AND
    /// - 잠긴 기준이 존재·잠금·**완전 decode**되고(누락·손상·범위 밖 임계값이면 fail-closed → 미종결), AND
    /// - ≥1 항목이 있고 **모든 항목**이 위험도 입력 + CURRENT한 결정(불완전·stale이면 미종결)을 가지며, AND
    /// - **기준 초과** 항목(현재 결정 기준)이 ≥1 개선조치를 갖고, 그 조치들이 **모두** 효과확인 완료 + 효과
    ///   있음(effective)이다. 부분 효과·효과 없음·미완료 → 미종결. 기준 초과 0건이면 finalized 즉시 종결.
    ///
    /// raw `criteriaDecision` 만으로 필수 조치·종결을 확정하지 않는다 — 잠긴 기준으로 재계산해 확인한다.
    public static func isClosed(_ assessment: RiskAssessment, in context: ModelContext) -> Bool {
        guard assessment.status == .finalized else { return false }
        guard let stored = assessment.criteria, stored.lockedAt != nil else { return false }
        guard let criteria = try? AcceptabilityCriteria.decode(
            from: stored, usesFrequencySeverity: assessment.method.usesFrequencySeverity)
        else { return false }
        guard let items = assessment.items, !items.isEmpty else { return false }
        for item in items {
            guard item.riskLevel != nil, item.hasCurrentCriteriaDecision(under: criteria) else { return false }
            guard CorrectiveActionPolicy.needsCorrectiveActionPlan(item) else { continue }   // 기준 초과만 조치 필요
            let actions = item.correctiveActions ?? []
            guard !actions.isEmpty else { return false }          // 계획 없음 → 미종결
            for action in actions where !CorrectiveActionPolicy.isEffectivelyResolved(action) { return false }
        }
        // KR 관할 추가 조건(WO LEGAL-2d §4): 현재 평가·조치 상태와 일치하는 **사후 공유 기록**(SharingEvent
        // 또는 확정 TBM 브리핑, WO LEGAL-TBM-4 §2.1)이 있어야 종결로 파생한다 — 개선조치가 바뀌면 이전
        // 사후 공유는 현재 상태 공유가 아니므로 다시 미종결. US·관할 미설정에는 이 조건을 강제하지 않는다.
        guard SharingEventPolicy.satisfiesPostSharingGate(assessment, in: context) else { return false }
        return true
    }

    /// 아직 종결이 아닌 **이유**. 화면이 "개선조치 N건 진행 중" 같은 문구를 스스로 추측하면 실제 막고 있는
    /// 조건과 어긋난다(예: 필수 조치가 0건인데 사후 공유가 없어서 미종결인 경우). 그래서 사유도 `isClosed`
    /// 와 **같은 순서로** 여기서 파생한다 — 사실만 말하고 판정하지 않는다.
    public enum OpenReason: Equatable, Sendable {
        case notFinalized                       // 아직 확정 전
        case criteriaUnavailable                // 기준 누락·손상 (fail-closed)
        case noItems
        case itemsIncomplete(count: Int)        // 위험도 미입력 또는 결정이 현재 기준과 불일치
        case correctiveActionsOpen(count: Int)  // 효과확인까지 끝나지 않은 필수 조치
        case postSharingMissing                 // KR: 현재 상태와 일치하는 사후 공유 없음
    }

    /// 종결이면 `nil`, 아니면 첫 번째로 걸린 사유.
    public static func openReason(_ assessment: RiskAssessment, in context: ModelContext) -> OpenReason? {
        guard assessment.status == .finalized else { return .notFinalized }
        guard let stored = assessment.criteria, stored.lockedAt != nil,
              let criteria = try? AcceptabilityCriteria.decode(
                from: stored, usesFrequencySeverity: assessment.method.usesFrequencySeverity)
        else { return .criteriaUnavailable }
        guard let items = assessment.items, !items.isEmpty else { return .noItems }

        let incomplete = items.filter {
            $0.riskLevel == nil || !$0.hasCurrentCriteriaDecision(under: criteria)
        }.count
        if incomplete > 0 { return .itemsIncomplete(count: incomplete) }

        // 기준 초과 항목이 요구하는 조치 중 아직 효과확인까지 끝나지 않은 것.
        var openActions = 0
        for item in items where CorrectiveActionPolicy.needsCorrectiveActionPlan(item) {
            let actions = item.correctiveActions ?? []
            if actions.isEmpty { openActions += 1; continue }   // 계획 자체가 없음
            openActions += actions.filter { !CorrectiveActionPolicy.isEffectivelyResolved($0) }.count
        }
        if openActions > 0 { return .correctiveActionsOpen(count: openActions) }

        guard SharingEventPolicy.satisfiesPostSharingGate(assessment, in: context) else { return .postSharingMissing }
        return nil
    }
}
