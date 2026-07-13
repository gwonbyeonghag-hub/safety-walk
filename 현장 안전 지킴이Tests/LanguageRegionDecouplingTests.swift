import Testing
import Foundation
import SafetyWalkCore
@testable import 현장_안전_지킴이

// LEGAL-1: 표시 언어(AppLanguage)와 법적 관할(RegionProfile)은 독립 축이다.
// These touch the shared LocalizationManager singleton + UserDefaults.standard, so the
// suite is serialized and every test snapshots/restores the keys it mutates.

@MainActor
@Suite("LEGAL-1 — language/region decoupling", .serialized)
struct LanguageRegionDecouplingTests {

    private let regionKey = "com.safetywalk.regionProfile"
    private let langKey   = "com.safetywalk.appLanguage"

    /// Runs `body` with the region + language keys restored afterwards.
    private func withRestoredDefaults(_ body: () -> Void) {
        let d = UserDefaults.standard
        let savedRegion = d.string(forKey: regionKey)
        let savedLang = LocalizationManager.shared.language
        defer {
            if let savedRegion { d.set(savedRegion, forKey: regionKey) }
            else { d.removeObject(forKey: regionKey) }
            LocalizationManager.shared.set(savedLang)
        }
        body()
    }

    // ① 디커플링 핵심: 언어를 바꿔도 region이 언어에서 파생되지 않는다.
    @Test func changingLanguageLeavesRegionUnchanged() {
        withRestoredDefaults {
            RegionProfileStore.set(.korea)               // region = Korea …
            LocalizationManager.shared.set(.english)     // … while language → English
            #expect(RegionProfileStore.get() == .korea)  // NOT forced to .global

            RegionProfileStore.set(.global)              // region = Global …
            LocalizationManager.shared.set(.korean)      // … while language → Korean
            #expect(RegionProfileStore.get() == .global) // NOT forced to .korea
        }
    }

    // ② 지역 set → get 왕복 persist.
    @Test func regionPersistsRoundTrip() {
        withRestoredDefaults {
            RegionProfileStore.set(.global)
            #expect(RegionProfileStore.get() == .global)
            RegionProfileStore.set(.korea)
            #expect(RegionProfileStore.get() == .korea)
        }
    }

    // ③ 첫 실행(미저장) 기본 = .korea.
    @Test func defaultRegionIsKoreaWhenUnset() {
        withRestoredDefaults {
            UserDefaults.standard.removeObject(forKey: regionKey)
            #expect(RegionProfileStore.get() == .korea)
        }
    }
}
