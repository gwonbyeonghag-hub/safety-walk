import Foundation

/// 위험 스냅샷 항목 하나의 비교 가능한 값 — `SharingSnapshot.Item` 이 `SharingEvent` 에 대해 하는 역할을
/// `BriefingRiskItemSnapshot` 에 대해 한다(WO LEGAL-TBM-4 §2.1). `BriefingLifecycle.conduct` 가 스냅샷을
/// 만들 때와 `SharingEventPolicy.isCurrent(_:SafetyBriefing:in:)` 가 최신성을 판정할 때 **같은 값 계산**을
/// 재사용해, 둘이 서로 다른 계산으로 갈라지지 않게 한다.
struct BriefingRiskItemContent: Equatable {
    let taskDescription: String
    let hazardDescription: String
    let currentControls: String
    let riskLevel: RiskLevel?
    let likelihood: Int?
    let severity: Int?
    let measures: [BriefingControlMeasureSnapshot]

    /// 평가 항목의 **현재** 값 — 지금 다시 브리핑을 진행한다면 만들어질 내용.
    static func current(from item: RiskAssessmentItem) -> BriefingRiskItemContent {
        BriefingRiskItemContent(
            taskDescription: item.taskDescription,
            hazardDescription: item.hazardDescription,
            currentControls: item.currentControls ?? "",
            riskLevel: item.riskLevel,
            likelihood: item.likelihood,
            severity: item.severity,
            measures: CorrectiveActionPolicy.sortedCorrectiveActions(item).map {
                BriefingControlMeasureSnapshot(
                    actionId: $0.id, measure: $0.measure, responsibleName: $0.responsibleName,
                    dueDate: $0.dueDate, status: $0.status.rawValue, postRiskLevel: $0.postRiskLevel?.rawValue)
            })
    }

    /// 저장된 스냅샷을 읽어온 값 — `controlMeasuresSnapshot` decode 실패는 fail-closed 로 던진다
    /// (`BriefingControlMeasuresSnapshot` 의 계약과 동일, 현재 값으로 대체하지 않는다).
    static func recorded(from snapshot: BriefingRiskItemSnapshot) throws -> BriefingRiskItemContent {
        let decoded = try BriefingControlMeasuresSnapshot.decode(
            snapshot.controlMeasuresSnapshot, formatVersion: snapshot.controlMeasuresFormatVersion)
        return BriefingRiskItemContent(
            taskDescription: snapshot.taskDescription,
            hazardDescription: snapshot.hazardDescription,
            currentControls: snapshot.currentControls,
            riskLevel: snapshot.riskLevel,
            likelihood: snapshot.likelihood,
            severity: snapshot.severity,
            measures: decoded.measures)
    }
}
