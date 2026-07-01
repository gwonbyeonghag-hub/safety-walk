import Foundation
import SwiftData
import SafetyWalkCore

/// The macOS shell's SwiftData stack. In DEBUG it is an **in-memory** store populated with
/// seed data so the dashboard and reports can be built and reviewed without an iCloud
/// account (WO-4 is account-independent). The container is intentionally the single swap
/// point for WO-3: CloudKit only has to change the `ModelConfiguration` here (e.g.
/// `.cloudKitDatabase(...)`) — no view or model change.
enum MacModelContainer {

    static let schema = Schema([
        Site.self,
        Area.self,
        Inspection.self,
        ChecklistItem.self,
        Hazard.self,
        RiskAssessment.self,
        RiskAssessmentItem.self,
    ])

    static let shared: ModelContainer = make()

    private static func make() -> ModelContainer {
        #if DEBUG
        // Ephemeral seeded store — deterministic each launch, no persisted cruft while the
        // shell is under development. WO-3 replaces this branch with the CloudKit store.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        #else
        let configuration = ModelConfiguration(schema: schema)
        #endif

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            #if DEBUG
            SeedData.populate(container.mainContext)
            #endif
            return container
        } catch {
            fatalError("Failed to create the macOS ModelContainer: \(error)")
        }
    }
}
