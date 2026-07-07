import Foundation
import SwiftData

/// Shared CloudKit `ModelContainer` factory for both apps (WO-9). Replaces the old
/// `fatalError`-on-failure closures in `SafetyWalkApp.swift` (iOS) and
/// `MacModelContainer.swift` (macOS Release): if the on-disk store can't be opened
/// (corruption, or a store from an unknown schema — the macOS Release crash this fixes,
/// and the F-1 defense on iOS), the store is moved aside and a fresh one is tried, so the
/// app always launches instead of trapping.
public enum SafetyWalkModelContainer {

    /// Production entry point. Builds the CloudKit-backed container for the shared v2 schema,
    /// recovering rather than crashing if its store can't be opened.
    public static func makeCloudKitContainer(containerID: String) -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        return makeRecoverable(
            schema: schema,
            migrationPlan: SafetyWalkMigrationPlan.self,
            storeURL: defaultStoreURL,
            backupSuffix: backupTimestamp()
        ) {
            ModelConfiguration(schema: schema, cloudKitDatabase: .private(containerID))
        }
    }

    /// The location SwiftData uses for a `ModelConfiguration` created without an explicit
    /// `url:` — `Application Support/default.store` (inside the sandbox container once the
    /// app is sandboxed). We deliberately do NOT pass an explicit `url:` to
    /// `ModelConfiguration`: that would relocate the store and orphan existing data (WO-9).
    /// We only need this path so recovery knows which files to move aside.
    static var defaultStoreURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("default.store")
    }

    private static func backupTimestamp() -> String {
        String(Int(Date().timeIntervalSince1970))
    }

    /// Tries to build `configuration()`'s container. On failure it moves `storeURL` (and its
    /// `-shm`/`-wal` sidecars) aside under `backupSuffix` and retries once against a fresh
    /// store; if that still fails it returns an in-memory store so the app always launches.
    /// `storeURL` must be where `configuration()` actually persists (the default location in
    /// production, a temp URL in tests).
    static func makeRecoverable(
        schema: Schema,
        migrationPlan: (any SchemaMigrationPlan.Type)?,
        storeURL: URL,
        backupSuffix: String,
        configuration: () -> ModelConfiguration
    ) -> ModelContainer {
        if let container = try? build(schema, migrationPlan, configuration()) {
            return container
        }
        // The store exists but can't be opened — set it aside (preserved) and try fresh.
        moveStoreAside(storeURL: storeURL, backupSuffix: backupSuffix)
        if let container = try? build(schema, migrationPlan, configuration()) {
            return container
        }
        // Last resort: an in-memory store of a valid schema can't fail for on-disk reasons,
        // so the app still opens (empty; CloudKit re-syncs on the next healthy launch).
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: memory)
    }

    private static func build(
        _ schema: Schema,
        _ plan: (any SchemaMigrationPlan.Type)?,
        _ configuration: ModelConfiguration
    ) throws -> ModelContainer {
        if let plan {
            return try ModelContainer(for: schema, migrationPlan: plan, configurations: configuration)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Moves `storeURL` and its SQLite sidecars (`-shm`, `-wal`) to sibling `.<suffix>.bak`
    /// files. It never deletes: the original store could hold the user's only copy of
    /// not-yet-synced data, and the project rule forbids destroying a store we didn't create.
    /// Returns the backup URLs actually created (missing sidecars are skipped).
    @discardableResult
    static func moveStoreAside(
        storeURL: URL,
        backupSuffix: String,
        fileManager: FileManager = .default
    ) -> [URL] {
        var moved: [URL] = []
        for path in [storeURL.path, storeURL.path + "-shm", storeURL.path + "-wal"] {
            guard fileManager.fileExists(atPath: path) else { continue }
            let destination = URL(fileURLWithPath: path + ".\(backupSuffix).bak")
            try? fileManager.removeItem(at: destination)  // clear a same-suffix leftover
            do {
                try fileManager.moveItem(at: URL(fileURLWithPath: path), to: destination)
                moved.append(destination)
            } catch {
                // Best effort: if a file can't be moved, the fresh retry fails again and we
                // fall through to the in-memory store — still no crash.
            }
        }
        return moved
    }
}
