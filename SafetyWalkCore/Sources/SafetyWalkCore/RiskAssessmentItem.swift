import Foundation
import SwiftData

/// 위험성평가 항목 (Risk Assessment Item) — one row of an assessment.
/// `riskLevel` always holds the RESOLVED 위험성 수준: for `.threeLevel` the user
/// sets it directly; for `.frequencySeverity` it is derived from
/// `likelihood × severity` via `RiskMatrixConfig.band(forScore:)`.
/// CloudKit-ready: optional/defaulted attributes, no `.unique`.
@Model
public final class RiskAssessmentItem {
    public var id: UUID = UUID()
    public var taskDescription: String = ""        // 공정/작업
    public var hazardDescription: String = ""      // 유해위험요인
    public var currentControls: String?            // 현재 안전조치
    public var likelihood: Int?                     // 가능성 1–3 (빈도×강도 전용; 3단계는 nil)
    public var severity: Int?                        // 중대성 1–3 (빈도×강도 전용; 3단계는 nil)
    public var riskLevel: RiskLevel = RiskLevel.low  // resolved 위험성 수준
    public var reductionMeasure: String?            // 감소대책
    public var postRiskLevel: RiskLevel?            // 개선 후 위험성 (선택)
    public var responsibleName: String?            // 담당
    public var dueDate: Date?                        // 개선예정일
    public var correctiveActionStatus: CorrectiveActionStatus = CorrectiveActionStatus.notStarted
    public var linkedHazardId: UUID?               // optional link to Hazard
    // Explicit ordering for JSA work steps; CloudKit does not preserve to-many order
    // (same reason ChecklistItem has sortOrder). Defaulted → CloudKit-safe.
    public var sortOrder: Int = 0
    // CloudKit-required inverse of RiskAssessment.items. Not read by app code —
    // containment in RiskAssessment.items remains the source of truth.
    public var riskAssessment: RiskAssessment?

    public init(
        taskDescription: String = "",
        hazardDescription: String = "",
        currentControls: String? = nil,
        likelihood: Int? = nil,
        severity: Int? = nil,
        // LEGAL-0: no default — every caller must pass a RESOLVED 위험성 수준 explicitly.
        // (The stored-property default on line 17 stays for CloudKit; only the
        // constructor default is removed so unassessed items can never be persisted.)
        riskLevel: RiskLevel,
        reductionMeasure: String? = nil,
        postRiskLevel: RiskLevel? = nil,
        responsibleName: String? = nil,
        dueDate: Date? = nil,
        correctiveActionStatus: CorrectiveActionStatus = .notStarted,
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
        self.reductionMeasure = reductionMeasure
        self.postRiskLevel = postRiskLevel
        self.responsibleName = responsibleName
        self.dueDate = dueDate
        self.correctiveActionStatus = correctiveActionStatus
        self.linkedHazardId = linkedHazardId
        self.sortOrder = sortOrder
    }
}
