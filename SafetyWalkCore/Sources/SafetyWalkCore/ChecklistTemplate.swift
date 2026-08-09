import Foundation

// Non-persistent structs. Loaded from JSON at runtime by ChecklistTemplateLoader.
// These are never stored in SwiftData — they are read-only configuration data.
//
// nonisolated init(from:) on each struct opts the Decodable conformance out of the
// implicit @MainActor isolation that SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor applies
// to all app-target declarations. Without this, JSONDecoder().decode(_:from:) called
// from a nonisolated context produces a "main actor-isolated conformance" warning.
// CodingKeys are declared so Swift can still synthesize encode(to:).

/// Federal OSHA industry scope a checklist template was authored against — General Industry
/// (29 CFR 1910) or Construction (29 CFR 1926). Deliberately separate from `IndustryProfileCode`
/// (위험성평가 업종 축, general/construction/electric) — checklist templates and risk-assessment
/// industry profiles are independent domain concepts that must not be conflated (WO LEGAL-3B);
/// this type also has no `.electric` case, so nothing can accidentally imply a third checklist
/// template.
public enum ChecklistIndustryScope: String, Codable, CaseIterable, Identifiable, Hashable {
    case general
    case construction

    public var id: String { rawValue }
}

/// One official primary source (OSHA/eCFR) that a template's items cite. `standardNumber` is the
/// human-readable citation (e.g. "29 CFR 1910.28"); `url` is the official osha.gov page for it.
/// WO LEGAL-3B §C — machine-verifiable source metadata, not free-text.
public struct ChecklistSourceReference: Codable, Identifiable, Hashable {
    public let id: String
    public let standardNumber: String
    public let url: String

    public nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        standardNumber = try c.decode(String.self, forKey: .standardNumber)
        url = try c.decode(String.self, forKey: .url)
    }

    private enum CodingKeys: String, CodingKey {
        case id, standardNumber, url
    }
}

public struct ChecklistTemplate: Codable, Identifiable {
    public let id: String
    public let regionProfile: RegionProfile
    public let name: String
    public let categories: [ChecklistCategory]
    // WO LEGAL-3B §C: optional/defaulted so the pre-existing template JSON (checklist_korea.json,
    // checklist_global.json) keeps decoding unchanged with no source metadata — only the new US
    // Federal templates populate these. Core tests enforce non-nil/non-empty for the new templates.
    public let version: String?
    public let industryScope: ChecklistIndustryScope?
    public let reviewedOn: String?
    public let sourceCatalog: [ChecklistSourceReference]?

    public nonisolated init(from decoder: any Decoder) throws {
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
        version = try c.decodeIfPresent(String.self, forKey: .version)
        industryScope = try c.decodeIfPresent(ChecklistIndustryScope.self, forKey: .industryScope)
        reviewedOn = try c.decodeIfPresent(String.self, forKey: .reviewedOn)
        sourceCatalog = try c.decodeIfPresent([ChecklistSourceReference].self, forKey: .sourceCatalog)
    }

    private enum CodingKeys: String, CodingKey {
        case id, regionProfile, name, categories, version, industryScope, reviewedOn, sourceCatalog
    }
}

public struct ChecklistCategory: Codable, Identifiable {
    public let id: String
    // titleKey maps to a LocalizationKey raw value so titles are always localized
    public let titleKey: String
    public let items: [ChecklistTemplateItem]

    public nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titleKey = try c.decode(String.self, forKey: .titleKey)
        items = try c.decode([ChecklistTemplateItem].self, forKey: .items)
    }

    private enum CodingKeys: String, CodingKey {
        case id, titleKey, items
    }
}

public struct ChecklistTemplateItem: Codable, Identifiable {
    public let id: String
    public let titleKey: String
    public let descriptionKey: String?
    // WO LEGAL-3B §C: which of the template's sourceCatalog entries back this item, by id.
    // Optional/nil for legacy items (checklist_korea.json / checklist_global.json); Core tests
    // require every new US Federal template item to carry at least one, and every id used here
    // to actually exist in that template's sourceCatalog (no orphans).
    public let sourceIds: [String]?

    public nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titleKey = try c.decode(String.self, forKey: .titleKey)
        descriptionKey = try c.decodeIfPresent(String.self, forKey: .descriptionKey)
        sourceIds = try c.decodeIfPresent([String].self, forKey: .sourceIds)
    }

    private enum CodingKeys: String, CodingKey {
        case id, titleKey, descriptionKey, sourceIds
    }
}
