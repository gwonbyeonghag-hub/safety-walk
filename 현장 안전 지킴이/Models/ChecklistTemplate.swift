import Foundation

// Non-persistent structs. Loaded from JSON at runtime by ChecklistTemplateLoader.
// These are never stored in SwiftData — they are read-only configuration data.
//
// nonisolated init(from:) on each struct opts the Decodable conformance out of the
// implicit @MainActor isolation that SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor applies
// to all app-target declarations. Without this, JSONDecoder().decode(_:from:) called
// from a nonisolated context produces a "main actor-isolated conformance" warning.
// CodingKeys are declared so Swift can still synthesize encode(to:).

struct ChecklistTemplate: Codable, Identifiable {
    let id: String
    let regionProfile: RegionProfile
    let name: String
    let categories: [ChecklistCategory]

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        let rawProfile = try c.decode(String.self, forKey: .regionProfile)
        guard let rp = RegionProfile(rawValue: rawProfile) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: c.codingPath + [CodingKeys.regionProfile],
                    debugDescription: "Unknown regionProfile value: '\(rawProfile)'"
                )
            )
        }
        regionProfile = rp
        name = try c.decode(String.self, forKey: .name)
        categories = try c.decode([ChecklistCategory].self, forKey: .categories)
    }

    private enum CodingKeys: String, CodingKey {
        case id, regionProfile, name, categories
    }
}

struct ChecklistCategory: Codable, Identifiable {
    let id: String
    // titleKey maps to a LocalizationKey raw value so titles are always localized
    let titleKey: String
    let items: [ChecklistTemplateItem]

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titleKey = try c.decode(String.self, forKey: .titleKey)
        items = try c.decode([ChecklistTemplateItem].self, forKey: .items)
    }

    private enum CodingKeys: String, CodingKey {
        case id, titleKey, items
    }
}

struct ChecklistTemplateItem: Codable, Identifiable {
    let id: String
    let titleKey: String
    let descriptionKey: String?

    nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titleKey = try c.decode(String.self, forKey: .titleKey)
        descriptionKey = try c.decodeIfPresent(String.self, forKey: .descriptionKey)
    }

    private enum CodingKeys: String, CodingKey {
        case id, titleKey, descriptionKey
    }
}
