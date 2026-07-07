import SwiftUI
import SafetyWalkCore
import SwiftData

@main
struct SafetyWalkApp: App {

    // App-wide appearance preference. Same key is bound by SettingsView's picker;
    // SwiftUI republishes the change automatically, so toggling Light/Dark/System
    // re-renders the whole tree without a restart.
    @AppStorage("com.safetywalk.appearanceMode")
    private var appearanceMode: AppearanceMode = .system

    // Drives live language switching. Observing the shared manager re-evaluates this
    // scene when the language changes; `.id(loc.language)` then rebuilds the whole tree
    // so every localized string re-renders in the new language without a restart.
    @State private var loc = LocalizationManager.shared

    // CloudKit-backed store (WO-3). Same container id + migration plan as
    // SafetyWalkMac/MacModelContainer.swift so both apps sync through one iCloud
    // container. VersionedSchema/SafetyWalkMigrationPlan lives in SafetyWalkCore so a
    // schema change only has to be made once for both targets (SWIFTDATA_MIGRATION.md).
    // The shared factory recovers instead of trapping if the store can't be opened
    // (WO-9 / F-1 defense) — see SafetyWalkCore/ModelContainerFactory.swift.
    static let modelContainer: ModelContainer =
        SafetyWalkModelContainer.makeCloudKitContainer(containerID: "iCloud.com.gwonbyeonghag.safetywalk")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: loc.language.rawValue))
                .id(loc.language)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .modelContainer(Self.modelContainer)
    }
}

extension AppearanceMode {
    // nil → follow system. Returned to `.preferredColorScheme` at the root scene.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
