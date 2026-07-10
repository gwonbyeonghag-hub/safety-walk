import Foundation
import SwiftData
import SafetyWalkCore

/// The macOS shell's SwiftData stack. In DEBUG it is an **in-memory** store populated with
/// seed data so the dashboard and reports can be built and reviewed without an iCloud
/// account (WO-4 is account-independent). In Release it's the same CloudKit-backed store
/// (container id + `SafetyWalkMigrationPlan`) as the iOS app's `SafetyWalkApp.swift`, so
/// both apps sync through one iCloud container.
enum MacModelContainer {

    static let schema = Schema(versionedSchema: SchemaV2.self)

    static let shared: ModelContainer = make()

    private static func make() -> ModelContainer {
        #if DEBUG
        // Ephemeral seeded store — deterministic each launch, no persisted cruft while the
        // shell is under development. In-memory stores don't sync via CloudKit, so DEBUG
        // stays account-independent (WO-4).
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            SeedData.populate(container.mainContext)
            return container
        } catch {
            fatalError("Failed to create the macOS ModelContainer: \(error)")
        }
        #else
        // Sandboxed (WO-9) so the store lives in the app's own container, not the shared
        // ~/Library/Application Support/default.store that caused the Release crash. The
        // shared factory also recovers instead of trapping if the store can't be opened.
        return SafetyWalkModelContainer.makeCloudKitContainer(containerID: "iCloud.com.gwonbyeonghag.safetywalk")
        #endif
    }
}
