import Foundation
import Observation

@Observable
final class SettingsViewModel {

    private static let inspectorNameKey = "com.safetywalk.inspectorName"

    var inspectorName: String {
        didSet { UserDefaults.standard.set(inspectorName, forKey: Self.inspectorNameKey) }
    }

    // Region profile is no longer a standalone setting — it is selected implicitly by the
    // Language toggle (see LocalizationManager). It remains persisted via RegionProfileStore
    // and continues to drive checklist-template loading.

    let appVersion: String

    init() {
        inspectorName = UserDefaults.standard.string(forKey: Self.inspectorNameKey) ?? ""

        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build  = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (short, build) {
        case let (s?, b?): appVersion = "\(s) (\(b))"
        case let (s?, nil): appVersion = s
        default:            appVersion = "Unknown"
        }
    }
}
