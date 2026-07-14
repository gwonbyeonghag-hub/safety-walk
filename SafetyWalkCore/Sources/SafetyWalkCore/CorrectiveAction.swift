import Foundation
import SwiftData

/// 개선(감소)대책 — one corrective action under a `RiskAssessmentItem` (SCHEMA_V3 §4). Absorbs
/// the old per-item improvement fields (measure/responsible/due/status/postRiskLevel) and adds
/// 효과확인. `isRequired` is NOT stored — it is derived from the parent item's 초과 여부
/// (교정 #2). 효과확인 결과는 Bool이 아니라 `effectivenessResult`(nil=미확인). CloudKit-ready.
@Model
public final class CorrectiveAction {
    public var id: UUID = UUID()
    public var measure: String?
    public var responsibleName: String?
    public var dueDate: Date?
    public var status: CorrectiveActionStatus = CorrectiveActionStatus.notStarted
    public var implementedAt: Date?
    public var confirmedBy: String?
    public var effectivenessConfirmedAt: Date?       // 감사 시각(교정 #6)
    public var effectivenessResult: EffectivenessResult?  // nil=미확인(교정 #2)
    @Attribute(.externalStorage) public var evidencePhotoData: Data?
    public var postRiskLevel: RiskLevel?
    // CloudKit-required inverse of RiskAssessmentItem.correctiveActions.
    public var item: RiskAssessmentItem?

    /// SCHEMA_V3 §4.1 생성자 계약: `item` connection is REQUIRED. `isRequired` is neither a
    /// stored field nor an init arg — it is derived from the parent item's 초과 여부.
    public init(
        item: RiskAssessmentItem,
        measure: String? = nil,
        responsibleName: String? = nil,
        dueDate: Date? = nil,
        status: CorrectiveActionStatus = .notStarted,
        postRiskLevel: RiskLevel? = nil
    ) {
        self.id = UUID()
        self.item = item
        self.measure = measure
        self.responsibleName = responsibleName
        self.dueDate = dueDate
        self.status = status
        self.postRiskLevel = postRiskLevel
    }

    /// 저장 안 함 → 부모 item.criteriaDecision == exceedsThreshold 에서 파생(교정 #2).
    public var isRequired: Bool {
        item?.criteriaDecision == .exceedsThreshold
    }

    /// "효과확인됨"은 result≠nil로 파생 (Bool 제거, 교정 #2).
    public var isEffectivenessConfirmed: Bool {
        effectivenessResult != nil
    }

    /// 효과확인 불변조건 (SCHEMA_V3 §4.1): result·effectivenessConfirmedAt·confirmedBy 는
    /// **하나의 도메인 동작으로 함께 갱신** — 부분 갱신 금지. 개별 setter 대신 항상 이 함수로.
    public func confirmEffectiveness(
        result: EffectivenessResult,
        by confirmedBy: String,
        at date: Date = Date()
    ) {
        self.effectivenessResult = result
        self.confirmedBy = confirmedBy
        self.effectivenessConfirmedAt = date
    }
}
