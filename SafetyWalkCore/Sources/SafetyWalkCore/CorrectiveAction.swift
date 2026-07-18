import Foundation
import SwiftData

/// 개선(감소)대책 — one corrective action under a `RiskAssessmentItem` (SCHEMA_V3 §4). Absorbs the old
/// per-item improvement fields (measure/responsible/due/status/postRiskLevel) and adds 효과확인.
/// CloudKit-ready (all attributes optional/defaulted, no `.unique`).
///
/// This `@Model` body is a pure DATA container: stored properties + relationships + an `internal`
/// data initializer that performs **no** validation and throws nothing. Every WO LEGAL-2c rule —
/// creation validation (비공백 감소대책·항상 미착수), 조치 필요/효과확인 완료·종결·확인 가능 판정,
/// 상태별 필드 정규화, 효과확인 무효화·기록, field snapshot/restore, 결정적 정렬 — lives in the
/// INDEPENDENT `CorrectiveActionPolicy` type, never in this body and never as an extension on it.
///
/// The initializer is deliberately **not** `public`: outside the package a `CorrectiveAction` can only
/// come from `CorrectiveActionPolicy.makeDraft` (validated draft, e.g. a `.planned` assessment being
/// authored) or `CorrectiveActionEditing.add` (validated + atomically persisted). There is no way for
/// app/macOS code to bypass validation by constructing the model directly.
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

    /// Plain data initializer — assigns the given values and nothing else. It has no `status`/
    /// `implementedAt`/`postRiskLevel`/효과확인 parameters, so a newly built action necessarily carries
    /// the stored defaults (`.notStarted`, everything else nil); the completed lifecycle is reached only
    /// through `CorrectiveActionEditing`. Validation of `measure` belongs to
    /// `CorrectiveActionPolicy.makeDraft`, the single create gate — this body performs none.
    init(
        item: RiskAssessmentItem,
        measure: String,
        responsibleName: String? = nil,
        dueDate: Date? = nil
    ) {
        self.id = UUID()
        self.item = item
        self.measure = measure
        self.responsibleName = responsibleName
        self.dueDate = dueDate
    }
}
