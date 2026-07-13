import Foundation
import Observation

/// The app's UI language — an axis fully independent of `RegionProfile` (the legal
/// jurisdiction). Changing the language never changes the region: a Korean-reading
/// manager on a US site and an English-reading manager on a Korean site are both
/// supported (LEGAL-1). Region is chosen separately via `RegionProfileStore`.
///
/// - `English` ⇒ locale `en`
/// - `한국어`  ⇒ locale `ko`
enum AppLanguage: String, CaseIterable, Hashable {
    case korean  = "ko"
    case english = "en"
}

/// Single source of truth for the in-app language. Swapping `language` also swaps the
/// `.lproj` `bundle` that every localized lookup reads from, so changing it (and forcing
/// a tree rebuild via `.id` in `SafetyWalkApp`) re-renders the whole UI in the new
/// language without an app restart. Persisted to `UserDefaults`; defaults to the system
/// language on first launch.
@Observable
final class LocalizationManager {

    static let shared = LocalizationManager()

    private static let key = "com.safetywalk.appLanguage"

    private(set) var language: AppLanguage
    private(set) var bundle: Bundle

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        let sys: AppLanguage = (Locale.current.language.languageCode?.identifier == "ko") ? .korean : .english
        let lang = AppLanguage(rawValue: saved ?? "") ?? sys
        language = lang
        bundle = Self.bundle(for: lang)
    }

    /// Switches the active language and swaps the `.lproj` bundle. Persists the choice for
    /// the next launch. Region (`RegionProfile`) is a separate axis and is deliberately
    /// NOT touched here — the two were decoupled in LEGAL-1.
    func set(_ lang: AppLanguage) {
        language = lang
        bundle = Self.bundle(for: lang)
        UserDefaults.standard.set(lang.rawValue, forKey: Self.key)
    }

    /// Resolves a raw `Localizable.strings` key through the active language bundle.
    /// Used by `LocalizationKey.localized` and by data-driven checklist template keys
    /// (`titleKey` / `categoryKey`) that are not part of the `LocalizationKey` enum.
    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private static func bundle(for lang: AppLanguage) -> Bundle {
        guard let p = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
              let b = Bundle(path: p) else { return .main }
        return b
    }
}

/// Resolves a data-driven `Localizable.strings` key (e.g. a checklist template
/// `titleKey` / `categoryKey` decoded from JSON) through the app's currently selected
/// language bundle — the non-enum counterpart to `LocalizationKey.localized`.
/// Every localized string in the app goes through `LocalizationManager.shared.bundle`,
/// so the live language toggle applies uniformly.
func L(_ key: String) -> String {
    LocalizationManager.shared.string(key)
}
