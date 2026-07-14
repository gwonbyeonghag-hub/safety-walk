import Foundation
import SwiftData

/// SchemaV3 (3.0.0) — the **first-launch baseline** (SCHEMA_V3.md §2). The project reset to
/// V3, so there is NO migration source: `SchemaV1`, `SchemaV2`, and `SafetyWalkMigrationPlan`
/// were removed. All 15 models are registered here — omitting any one breaks the whole graph
/// (§1). Post-launch, a V3 shape is FROZEN and must never be edited in place; any change is a
/// new `SchemaV4` + migration (§2 동결 보존 정책).
public enum SchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            // 기존 5 (불변)
            Site.self, Area.self, Inspection.self, ChecklistItem.self, Hazard.self,
            // 기존 2 (확장)
            RiskAssessment.self, RiskAssessmentItem.self,
            // 신규 8
            RiskAssessmentProgram.self, AssessmentCriteria.self, CorrectiveAction.self,
            RiskAssessmentParticipant.self, SharingEvent.self,
            SafetyBriefing.self, BriefingParticipant.self, BriefingRiskItemSnapshot.self,
        ]
    }
}
