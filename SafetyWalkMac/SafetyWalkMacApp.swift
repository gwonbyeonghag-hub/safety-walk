import SwiftUI
import SwiftData
import SafetyWalkCore

/// SafetyWalk for Mac — the manager dashboard + report hub (WO-4). Shares SafetyWalkCore
/// (models/enums/templates) and the iOS app's localization + risk-color + report-engine
/// files via target membership; all macOS-specific UI lives under `SafetyWalkMac/`.
/// The data store comes from `MacModelContainer` (seeded in DEBUG) — WO-3 swaps it for
/// the CloudKit-backed store without touching any view.
@main
struct SafetyWalkMacApp: App {

    @AppStorage("com.safetywalk.appearanceMode")
    private var appearanceMode: AppearanceMode = .system

    @State private var loc = LocalizationManager.shared

    init() {
        #if DEBUG
        MacReportEvidence.dumpIfRequested()   // no-op unless mac.debug.dumpReports is set
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MacRootView()
                .environment(\.locale, Locale(identifier: loc.language.rawValue))
                .id(loc.language)
                .preferredColorScheme(appearanceMode.colorScheme)
                .frame(minWidth: 1040, minHeight: 680)
                .tint(Color.brandNavy)
                #if DEBUG
                .task { await MacScreenshotEvidence.dumpIfRequested() }   // no-op unless mac.debug.dumpScreenshots is set
                #endif
        }
        .modelContainer(MacModelContainer.shared)
        .commands {
            // Language toggle from the menu bar — mirrors the iOS Settings picker so the
            // manager can review reports in either language.
            CommandGroup(after: .toolbar) {
                Picker(LocalizationKey.macLanguage.localized, selection: Binding(
                    get: { loc.language },
                    set: { loc.set($0) }
                )) {
                    Text("한국어").tag(AppLanguage.korean)
                    Text("English").tag(AppLanguage.english)
                }
            }
        }
    }
}
