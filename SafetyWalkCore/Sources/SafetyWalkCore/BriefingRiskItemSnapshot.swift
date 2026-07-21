import Foundation
import SwiftData

/// 브리핑 당시 위험항목 값 스냅샷 (SCHEMA_V3 §4 — 교정 #3·#5). A full VALUE COPY of a source
/// `RiskAssessmentItem` at briefing time (문자열 축약 금지): the 정규 위험도 값 plus a versioned
/// snapshot of the item's 1:N corrective actions (each measure·담당·기한·status·postRiskLevel
/// value-copied; decode failure fail-closed). Source ids are kept for traceability only.
/// CloudKit-ready.
///
/// The initializer is deliberately **not** `public` (WO LEGAL-TBM-1 §4 "sealed로 Core 우회 불가"):
/// a snapshot only comes from `BriefingLifecycle.conduct`, the single moment a briefing copies its
/// linked assessment's items.
@Model
public final class BriefingRiskItemSnapshot {
    public var id: UUID = UUID()
    public var sourceAssessmentId: UUID?          // 출처 추적용
    public var sourceItemId: UUID?
    public var taskDescription: String = ""
    public var hazardDescription: String = ""
    public var currentControls: String = ""
    public var riskLevel: RiskLevel?              // ★정규 값 (nil=미평가)
    public var likelihood: Int?
    public var severity: Int?
    // ★1:N 조치 버전형 스냅샷 (JSON). 디코딩 실패 fail-closed.
    public var controlMeasuresSnapshot: Data = Data()
    public var controlMeasuresFormatVersion: Int = 1
    public var displayTextAtBriefing: String?     // 당시 표시 문구(선택 보존)
    // CloudKit-required inverse of SafetyBriefing.riskSnapshots.
    public var briefing: SafetyBriefing?

    init(
        sourceAssessmentId: UUID? = nil,
        sourceItemId: UUID? = nil,
        taskDescription: String = "",
        hazardDescription: String = "",
        currentControls: String = "",
        riskLevel: RiskLevel? = nil,
        likelihood: Int? = nil,
        severity: Int? = nil,
        controlMeasuresSnapshot: Data = Data(),
        controlMeasuresFormatVersion: Int = 1,
        displayTextAtBriefing: String? = nil
    ) {
        self.id = UUID()
        self.sourceAssessmentId = sourceAssessmentId
        self.sourceItemId = sourceItemId
        self.taskDescription = taskDescription
        self.hazardDescription = hazardDescription
        self.currentControls = currentControls
        self.riskLevel = riskLevel
        self.likelihood = likelihood
        self.severity = severity
        self.controlMeasuresSnapshot = controlMeasuresSnapshot
        self.controlMeasuresFormatVersion = controlMeasuresFormatVersion
        self.displayTextAtBriefing = displayTextAtBriefing
    }
}
