import Foundation
import SwiftData

/// 위험성평가 항목 (Risk Assessment Item) — one row of an assessment (SCHEMA_V3 §4).
/// V3 splits the old per-item improvement fields out into `CorrectiveAction` children, and
/// makes `riskLevel`/`criteriaDecision` optional: **nil = 미평가**, never auto-Low/기준내
/// (교정 #3). The user's 초과 여부 decision is recorded in `criteriaDecision` with the
/// confirming time/person; finalize-time validation enforces that every item is assessed.
/// CloudKit-ready: optional/defaulted attributes, no `.unique`.
@Model
public final class RiskAssessmentItem {
    public var id: UUID = UUID()
    public var taskDescription: String = ""        // 공정/작업
    public var hazardDescription: String = ""      // 유해위험요인
    public var currentControls: String?            // 현재 안전조치
    public var likelihood: Int?                     // 가능성 1–3 (빈도×강도 전용; 3단계는 nil)
    public var severity: Int?                        // 중대성 1–3 (빈도×강도 전용; 3단계는 nil)
    public var riskLevel: RiskLevel?               // ★optional — nil=미평가(교정 #3)
    public var criteriaDecision: CriteriaDecision? // nil=미평가, 초과 여부는 사용자 확인
    public var decisionConfirmedAt: Date?          // 결정 확인 시각(교정 #3)
    public var decisionConfirmedBy: String?        // 결정 확인자(교정 #3)
    public var linkedHazardId: UUID?               // optional link to Hazard
    // Explicit ordering for JSA work steps; CloudKit does not preserve to-many order.
    public var sortOrder: Int = 0
    // CloudKit-required inverse of RiskAssessment.items. Not read by app code —
    // containment in RiskAssessment.items remains the source of truth.
    public var riskAssessment: RiskAssessment?
    // 리셋이라 legacy 이관 없음 — 개선대책은 CorrectiveAction 자식으로.
    @Relationship(deleteRule: .cascade, inverse: \CorrectiveAction.item) public var correctiveActions: [CorrectiveAction]?

    public init(
        taskDescription: String = "",
        hazardDescription: String = "",
        currentControls: String? = nil,
        likelihood: Int? = nil,
        severity: Int? = nil,
        riskLevel: RiskLevel? = nil,
        criteriaDecision: CriteriaDecision? = nil,
        decisionConfirmedAt: Date? = nil,
        decisionConfirmedBy: String? = nil,
        linkedHazardId: UUID? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.taskDescription = taskDescription
        self.hazardDescription = hazardDescription
        self.currentControls = currentControls
        self.likelihood = likelihood
        self.severity = severity
        self.riskLevel = riskLevel
        self.criteriaDecision = criteriaDecision
        self.decisionConfirmedAt = decisionConfirmedAt
        self.decisionConfirmedBy = decisionConfirmedBy
        self.linkedHazardId = linkedHazardId
        self.sortOrder = sortOrder
        self.correctiveActions = []
    }

    /// True once the user has assessed both the 위험성 수준 and the 허용기준 초과 여부.
    /// finalize 전 검증의 단위 조건 (SCHEMA_V3 §7).
    public var isAssessed: Bool {
        riskLevel != nil && criteriaDecision != nil
    }

    /// Interim single-action bridge: the item's corrective action, if any. The V3 create flow
    /// records one `CorrectiveAction` per item (measure/담당/기한/status); detail and the PDF
    /// reports read it back through here until the full 2c corrective-action UI lands.
    public var primaryCorrectiveAction: CorrectiveAction? {
        correctiveActions?.first
    }

    // 기준 이내/초과 CONFIRMATION is a Core domain operation that computes + validates the
    // suggestion from the locked criteria and the item's current input — see the
    // `confirmCriteriaDecision(under:at:by:)` / `hasCurrentCriteriaDecision(under:)` extension in
    // AcceptabilityCriteria.swift (WO LEGAL-2b §2). No arbitrary-decision setter exists.
}
