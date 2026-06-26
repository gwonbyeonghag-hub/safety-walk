import Foundation
import SafetyWalkCore

// Persists the user's selected RegionProfile to UserDefaults.
// All callers use RegionProfileStore.get() / .set() — no direct UserDefaults access elsewhere.
struct RegionProfileStore {

    private static let key = "com.safetywalk.regionProfile"

    static func get() -> RegionProfile {
        guard let raw = UserDefaults.standard.string(forKey: key) else {
            return .korea
        }
        return RegionProfile(storageCode: raw) ?? .korea
    }

    static func set(_ profile: RegionProfile) {
        UserDefaults.standard.set(profile.storageCode, forKey: key)
    }
}

// MARK: - Storage encoding

extension RegionProfile {
    // Short uppercase codes used in UserDefaults, distinct from the Swift enum raw value.
    var storageCode: String {
        switch self {
        case .korea:  return "KR"
        case .global: return "GLOBAL"
        }
    }

    // Returns nil for any unrecognised stored string so the caller can apply a safe default.
    init?(storageCode: String) {
        switch storageCode {
        case "KR":     self = .korea
        case "GLOBAL": self = .global
        default:       return nil
        }
    }
}
