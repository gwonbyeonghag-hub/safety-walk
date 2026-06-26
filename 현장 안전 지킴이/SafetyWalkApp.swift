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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: loc.language.rawValue))
                .id(loc.language)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .modelContainer(for: [
            Site.self,
            Area.self,
            Inspection.self,
            ChecklistItem.self,
            Hazard.self
        ])
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
