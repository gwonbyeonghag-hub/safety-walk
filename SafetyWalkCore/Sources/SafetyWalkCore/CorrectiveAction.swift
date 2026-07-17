import Foundation
import SwiftData

/// 개선(감소)대책 — one corrective action under a `RiskAssessmentItem` (SCHEMA_V3 §4). Absorbs the old
/// per-item improvement fields (measure/responsible/due/status/postRiskLevel) and adds 효과확인.
/// CloudKit-ready (all attributes optional/defaulted, no `.unique`).
///
/// This `@Model` body is a pure DATA container: stored properties + the sealed create contract. It holds
/// **no** business policy — every WO LEGAL-2c derivation and mutation (조치 필요/효과확인 완료·종결·확인
/// 가능 판정, 상태별 필드 정규화, 효과확인 무효화·기록, field snapshot/restore, 결정적 정렬) lives in the
/// INDEPENDENT `CorrectiveActionPolicy` type — never as an extension on this model. External code creates
/// through the sealed init and edits only through `CorrectiveActionEditing`.
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
}
