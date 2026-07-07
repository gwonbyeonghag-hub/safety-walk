import Foundation
import SwiftData

/// The current (WO-3, CloudKit) schema. Every model here is the live top-level
/// SafetyWalkCore type — this version exists only so `SafetyWalkMigrationPlan` has a
/// named destination to migrate `SchemaV1` into.
public enum SchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Site.self, Area.self, Inspection.self, ChecklistItem.self, Hazard.self,
         RiskAssessment.self, RiskAssessmentItem.self]
    }
}
