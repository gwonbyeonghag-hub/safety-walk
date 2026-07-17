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
    // WO LEGAL-2b P1-2: risk inputs + the confirmation triplet are `internal(set)` — app code sets
    // risk inputs only at creation (init), and after that must go through the Core mutation ops
    // (updateFrequencySeverityInput / updateDirectRiskLevel), which reset the confirmation on any
    // change. The confirmation triplet is Core-only (confirm/reset). SwiftData stored type/default
    // unchanged (no schema-field change).
    public internal(set) var likelihood: Int?       // 가능성 1–3 (빈도×강도 전용; 3단계는 nil)
    public internal(set) var severity: Int?         // 중대성 1–3 (빈도×강도 전용; 3단계는 nil)
    public internal(set) var riskLevel: RiskLevel?  // ★optional — nil=미평가(교정 #3)
    public internal(set) var criteriaDecision: CriteriaDecision? // nil=미평가, 초과 여부는 사용자 확인
    public internal(set) var decisionConfirmedAt: Date?          // 결정 확인 시각(교정 #3)
    public internal(set) var decisionConfirmedBy: String?        // 결정 확인자(교정 #3)
    public var linkedHazardId: UUID?               // optional link to Hazard
    // Explicit ordering for JSA work steps; CloudKit does not preserve to-many order.
    public var sortOrder: Int = 0
    // CloudKit-required inverse of RiskAssessment.items. Not read by app code —
    // containment in RiskAssessment.items remains the source of truth.
    public var riskAssessment: RiskAssessment?
    // 리셋이라 legacy 이관 없음 — 개선대책은 CorrectiveAction 자식으로.
    @Relationship(deleteRule: .cascade, inverse: \CorrectiveAction.item) public var correctiveActions: [CorrectiveAction]?

    /// Public init takes the item's risk inputs (creation only), but NOT the confirmation triplet
    /// — external app code can never inject an arbitrary "확정 완료" state (WO LEGAL-2b P1-2). A
    /// decision is only ever recorded through `confirmCriteriaDecision(under:at:by:)`.
    public init(
        taskDescription: String = "",
        hazardDescription: String = "",
        currentControls: String? = nil,
        likelihood: Int? = nil,
        severity: Int? = nil,
        riskLevel: RiskLevel? = nil,
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
        self.linkedHazardId = linkedHazardId
        self.sortOrder = sortOrder
        self.correctiveActions = []
    }

    /// True only for a COMPLETE confirmation: a resolved 위험성 수준 AND a decision with its
    /// confirming time and a non-blank confirmer (WO LEGAL-2b P2). nil/blank = 미평가.
    public var isAssessed: Bool {
        guard riskLevel != nil, criteriaDecision != nil, decisionConfirmedAt != nil,
              let by = decisionConfirmedBy, !by.sw_isBlank
        else { return false }
        return true
    }

    // 기준 이내/초과 CONFIRMATION is a Core domain operation that computes + validates the
    // suggestion from the locked criteria and the item's current input — see the
    // `confirmCriteriaDecision(under:at:by:)` / `hasCurrentCriteriaDecision(under:)` extension in
    // AcceptabilityCriteria.swift (WO LEGAL-2b §2). No arbitrary-decision setter exists.

    /// 빈도×강도/JSA 위험 입력 변경. Sets likelihood/severity and re-derives `riskLevel` from the
    /// locked `matrix`, keeping (l,s)↔riskLevel consistent. If ANY value actually changes, the
    /// confirmation triplet is reset — even when the resulting band is the same (WO P1-2: any risk
    /// change invalidates the prior confirmation). Identical input is a no-op (keeps confirmation).
    public func updateFrequencySeverityInput(likelihood newL: Int?, severity newS: Int?, using matrix: CriteriaMatrixSnapshot) {
        // Out-of-range / overflow inputs get NO risk level (nil=미평가, never auto-Low) — the same
        // range check the suggestion path uses, so the two never diverge (WO P1-3 · 최종 반송).
        let newLevel = matrix.inRangeBand(likelihood: newL, severity: newS)
        guard likelihood != newL || severity != newS || riskLevel != newLevel else { return }
        likelihood = newL
        severity = newS
        riskLevel = newLevel
        resetCriteriaDecision()
    }

    /// 3단계/체크리스트 위험등급 변경. If the level actually changes (or stale score inputs are
    /// cleared), the confirmation triplet is reset (WO P1-2). Identical input is a no-op.
    public func updateDirectRiskLevel(_ newLevel: RiskLevel?) {
        guard riskLevel != newLevel || likelihood != nil || severity != nil else { return }
        riskLevel = newLevel
        likelihood = nil
        severity = nil
        resetCriteriaDecision()
    }

    /// Clears the confirmation triplet (Core-only). Returns the item to 미평가.
    func resetCriteriaDecision() {
        criteriaDecision = nil
        decisionConfirmedAt = nil
        decisionConfirmedBy = nil
    }
}
