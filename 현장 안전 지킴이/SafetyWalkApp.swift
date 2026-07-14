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

    // Pro entitlement service (WO-10). Injected so the two gates (RA new-creation, report
    // export) can read `isPro`; free features never touch it. `start()` loads products +
    // resolves entitlements once the scene appears.
    @State private var proStore = ProStore()

    // CloudKit-backed store (WO-3). Same container id + SchemaV3 baseline as
    // SafetyWalkMac/MacModelContainer.swift so both apps sync through one iCloud
    // container. The VersionedSchema (SchemaV3) lives in SafetyWalkCore so a schema
    // change only has to be made once for both targets. V3 is a reset first-launch
    // baseline — no migration plan (SCHEMA_V3.md §2).
    // The shared factory recovers instead of trapping if the store can't be opened
    // (WO-9 / F-1 defense) — see SafetyWalkCore/ModelContainerFactory.swift.
    static let modelContainer: ModelContainer = makeModelContainer()

    private static func makeModelContainer() -> ModelContainer {
        #if DEBUG
        // Verification / screenshot runs only (WO-13): a throwaway in-memory store seeded
        // with backdated inspections. Gated on an explicit launch argument; never touches
        // the real CloudKit store. Compiled out of Release.
        if HistorySeed.isRequested {
            return HistorySeed.makeSeededInMemoryContainer()
        }
        #endif
        let container = SafetyWalkModelContainer.makeCloudKitContainer(containerID: "iCloud.com.gwonbyeonghag.safetywalk")
        #if DEBUG
        seedUITestSiteIfRequested(into: container)
        #endif
        return container
    }

    #if DEBUG
    /// UI-test site name for flows that require a site (RA create needs siteId·siteName per
    /// SCHEMA_V3 §4.1). Seeded only under the launch arg below; never ships (`#if DEBUG`).
    static let uitestSeedSiteName = "테스트 현장"

    /// Seeds one `Site` so a UI test can exercise the RA create flow's mandatory-site path.
    /// Idempotent — never duplicates on a relaunch against a persisted store.
    private static func seedUITestSiteIfRequested(into container: ModelContainer) {
        guard UserDefaults.standard.bool(forKey: "com.safetywalk.uitestSeedSite") else { return }
        let ctx = ModelContext(container)
        let sites = (try? ctx.fetch(FetchDescriptor<Site>())) ?? []
        guard !sites.contains(where: { $0.name == uitestSeedSiteName }) else { return }
        ctx.insert(Site(name: uitestSeedSiteName))
        try? ctx.save()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: loc.language.rawValue))
                .id(loc.language)
                .preferredColorScheme(appearanceMode.colorScheme)
                .environment(proStore)
                .task { await proStore.start() }
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
