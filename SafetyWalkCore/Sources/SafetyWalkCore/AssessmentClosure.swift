import Foundation

/// 종결(closed) 파생 — `closed` 는 저장 상태가 아니라 계산이다(LEGAL_2_ARCH §1.1). WO LEGAL-2c 는
/// finalize 전환을 소유하지 않고 이 파생만 제공한다: finalized 된 평가에서 모든 필수 개선조치의
/// 이행·효과확인이 끝나야 "종결"로 표시할 수 있다. (finalize 버튼/상태 전환은 후속 슬라이스.)
public enum AssessmentClosure {

    /// `closed` ⇔
    /// - 평가가 `.finalized`, AND
    /// - 잠긴 기준이 존재·잠금·**완전 decode**되고(누락·손상·범위 밖 임계값이면 fail-closed → 미종결), AND
    /// - ≥1 항목이 있고 **모든 항목**이 위험도 입력 + CURRENT한 결정(불완전·stale이면 미종결)을 가지며, AND
    /// - **기준 초과** 항목(현재 결정 기준)이 ≥1 개선조치를 갖고, 그 조치들이 **모두** 효과확인 완료 + 효과
    ///   있음(effective)이다. 부분 효과·효과 없음·미완료 → 미종결. 기준 초과 0건이면 finalized 즉시 종결.
    ///
    /// raw `criteriaDecision` 만으로 필수 조치·종결을 확정하지 않는다 — 잠긴 기준으로 재계산해 확인한다.
    public static func isClosed(_ assessment: RiskAssessment) -> Bool {
        guard assessment.status == .finalized else { return false }
        guard let stored = assessment.criteria, stored.lockedAt != nil else { return false }
        guard let criteria = try? AcceptabilityCriteria.decode(
            from: stored, usesFrequencySeverity: assessment.method.usesFrequencySeverity)
        else { return false }
        guard let items = assessment.items, !items.isEmpty else { return false }
        for item in items {
            guard item.riskLevel != nil, item.hasCurrentCriteriaDecision(under: criteria) else { return false }
            guard item.criteriaDecision == .exceedsThreshold else { continue }
            let actions = item.correctiveActions ?? []
            guard !actions.isEmpty else { return false }          // 계획 없음 → 미종결
            for action in actions where !action.isEffectivelyResolved { return false }
        }
        return true
    }
}
