import Foundation
import SwiftData

/// 허용기준 (Acceptability Criteria) — one per assessment, owned 1:1 with value-copied matrix
/// data (SCHEMA_V3 §4). Locked once the assessment goes inProgress (`lockedAt`); a decode
/// failure of `matrixData` is fail-closed (미평가 취급, 교정 #6 · §7). CloudKit-ready.
@Model
public final class AssessmentCriteria {
    public var id: UUID = UUID()
    public var matrixData: Data = Data()          // 값복사된 매트릭스 (JSON)
    public var matrixFormatVersion: Int = 1       // 포맷버전 + 디코딩 실패시 fail-closed
    public var acceptabilityThreshold: Int = 0
    public var lockedAt: Date?                     // inProgress 잠금 시각
    // CloudKit-required inverse of RiskAssessment.criteria.
    public var riskAssessment: RiskAssessment?

    public init(
        matrixData: Data = Data(),
        matrixFormatVersion: Int = 1,
        acceptabilityThreshold: Int = 0
    ) {
        self.id = UUID()
        self.matrixData = matrixData
        self.matrixFormatVersion = matrixFormatVersion
        self.acceptabilityThreshold = acceptabilityThreshold
    }
}
