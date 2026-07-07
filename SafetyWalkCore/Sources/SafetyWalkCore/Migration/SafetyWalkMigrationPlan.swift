import Foundation
import SwiftData

/// V1 → V2: retrofits the 5 v1 models for CloudKit (declaration defaults, optional
/// to-many relationships — lightweight, inferred automatically) and carries existing
/// `ChecklistItem`/`Hazard` evidence photos from the old file-path scheme
/// (`Documents/EvidencePhotos/<uuid>.jpg`) into the new CloudKit-synced `photoData`
/// field. Registered on both apps' `ModelContainer` (SWIFTDATA_MIGRATION.md).
public enum SafetyWalkMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    public static var stages: [MigrationStage] { [migrateV1toV2] }

    /// Carries `id -> legacy relative path` between `willMigrate` (old schema, photoPath
    /// still present) and `didMigrate` (new schema, photoData now present but empty) —
    /// the two closures run against different `ModelContext`s, so state can't be read
    /// back from the store itself between them.
    private final class LegacyPhotoPaths: @unchecked Sendable {
        var items: [UUID: String] = [:]
        var hazards: [UUID: String] = [:]
    }

    /// The pre-WO-3 PhotoStorageService root ("Documents"). Overridable so tests can
    /// point the migration at a temp directory instead of the real Documents folder.
    public static var legacyRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    private static let migrateV1toV2: MigrationStage = {
        let legacy = LegacyPhotoPaths()
        return .custom(
            fromVersion: SchemaV1.self,
            toVersion: SchemaV2.self,
            willMigrate: { context in
                for item in try context.fetch(FetchDescriptor<SchemaV1.ChecklistItem>()) {
                    if let path = item.photoPath, !path.isEmpty {
                        legacy.items[item.id] = path
                    }
                }
                for hazard in try context.fetch(FetchDescriptor<SchemaV1.Hazard>()) {
                    if !hazard.photoPath.isEmpty {
                        legacy.hazards[hazard.id] = hazard.photoPath
                    }
                }
            },
            didMigrate: { context in
                for item in try context.fetch(FetchDescriptor<ChecklistItem>()) {
                    guard let path = legacy.items[item.id] else { continue }
                    item.photoData = readLegacyFile(path)
                    deleteLegacyFile(path)
                }
                for hazard in try context.fetch(FetchDescriptor<Hazard>()) {
                    guard let path = legacy.hazards[hazard.id] else { continue }
                    hazard.photoData = readLegacyFile(path)
                    deleteLegacyFile(path)
                }
                try context.save()
            }
        )
    }()

    private static func readLegacyFile(_ relativePath: String) -> Data? {
        FileManager.default.contents(atPath: legacyRoot.appendingPathComponent(relativePath).path)
    }

    private static func deleteLegacyFile(_ relativePath: String) {
        try? FileManager.default.removeItem(at: legacyRoot.appendingPathComponent(relativePath))
    }
}
