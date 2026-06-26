import Foundation

// All domain enums. Names are canonical — see DOMAIN_TERMS.md before renaming.

enum ChecklistItemResult: String, Codable, CaseIterable, Hashable {
    case pass
    case fail
    case notApplicable
    case unchecked
}

enum RiskLevel: String, Codable, CaseIterable, Hashable, Comparable {
    case low
    case medium
    case high

    private static let order: [RiskLevel] = [.low, .medium, .high]

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

enum CorrectiveActionStatus: String, Codable, CaseIterable, Hashable {
    case notStarted
    case inProgress
    case completed
}

enum InspectionStatus: String, Codable, Hashable {
    case inProgress
    case completed
}

enum RegionProfile: String, Codable, CaseIterable, Hashable {
    case korea
    case global
}

enum HazardType: String, Codable, CaseIterable, Hashable {
    case fallRisk
    case electrical
    case fire
    case chemical
    case general
    case other
}

// Local app-appearance preference (Settings → Appearance). Persisted by raw
// String via @AppStorage; not a SwiftData model. Mapping to SwiftUI's
// `ColorScheme?` lives in SafetyWalkApp.swift to keep this file SwiftUI-free.
enum AppearanceMode: String, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }
}
