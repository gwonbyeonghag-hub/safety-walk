import Foundation
import SwiftData

/// 개선(감소)대책 — one corrective action under a `RiskAssessmentItem` (SCHEMA_V3 §4). Absorbs the
/// old per-item improvement fields (measure/responsible/due/status/postRiskLevel) and adds 효과확인.
/// CloudKit-ready (all attributes optional/defaulted, no `.unique`).
///
/// This `@Model` body is the DATA container only: stored properties + the sealed create contract +
/// the two baseline derivations (`isRequired`, `isEffectivenessConfirmed`) + the baseline atomic
/// 효과확인 setter. The WO LEGAL-2c lifecycle/mutation logic (status normalization, 효과확인 무효화,
/// completeness/resolution derivations, field snapshot/restore) lives in `CorrectiveActionPolicy` so
/// it stays out of the model body. The mutable value fields + the 효과확인 triplet are `internal(set)`
/// — external code creates through the sealed init and edits only through `CorrectiveActionEditing`.
@Model
public final class CorrectiveAction {
    public var id: UUID = UUID()
    public internal(set) var measure: String?
    public internal(set) var responsibleName: String?
    public internal(set) var dueDate: Date?
    public internal(set) var status: CorrectiveActionStatus = CorrectiveActionStatus.notStarted
    public internal(set) var implementedAt: Date?                 // 이행일
    public internal(set) var confirmedBy: String?                 // 효과 확인자
    public internal(set) var effectivenessConfirmedAt: Date?      // 감사 시각(교정 #6)
    public internal(set) var effectivenessResult: EffectivenessResult?  // nil=미확인(교정 #2)
    @Attribute(.externalStorage) public internal(set) var evidencePhotoData: Data?
    public internal(set) var postRiskLevel: RiskLevel?           // 개선 후 위험성
    // CloudKit-required inverse of RiskAssessmentItem.correctiveActions.
    public var item: RiskAssessmentItem?

    /// Sealed create contract (WO LEGAL-2c 3차): no `status`/`postRiskLevel` args — a new action is
    /// ALWAYS `.notStarted` with empty 이행일·개선후위험도·효과확인 — and a **non-blank `measure` is
    /// required**, so an empty/metadata-only/arbitrary-`.completed` action can't be created through
    /// the public API. The stored `measure` stays `String?` (CloudKit default) but this init blocks
    /// the empty string at creation. The completed lifecycle is reached only via `CorrectiveActionEditing`.
    public init(
        item: RiskAssessmentItem,
        measure: String,
        responsibleName: String? = nil,
        dueDate: Date? = nil
    ) throws {
        guard !measure.sw_isBlank else { throw CorrectiveActionError.emptyMeasure }
        self.id = UUID()
        self.item = item
        self.measure = measure
        self.responsibleName = responsibleName
        self.dueDate = dueDate
    }

    /// 저장 안 함 → 부모 item.criteriaDecision == exceedsThreshold 에서 파생(교정 #2). (baseline)
    public var isRequired: Bool {
        item?.criteriaDecision == .exceedsThreshold
    }

    /// "효과확인됨"은 result≠nil로 파생 (Bool 제거, 교정 #2). (baseline)
    public var isEffectivenessConfirmed: Bool {
        effectivenessResult != nil
    }

    /// 효과확인 불변조건 (SCHEMA_V3 §4.1): result·effectivenessConfirmedAt·confirmedBy 는 **하나의
    /// 도메인 동작으로 함께 갱신** — 부분 갱신 금지. Core-only(`internal`): 전제 검증·원자 저장은
    /// `CorrectiveActionEditing.confirmEffectiveness`가 담당. (baseline)
    func confirmEffectiveness(
        result: EffectivenessResult,
        by confirmedBy: String,
        at date: Date = Date()
    ) {
        self.effectivenessResult = result
        self.confirmedBy = confirmedBy
        self.effectivenessConfirmedAt = date
    }
}
