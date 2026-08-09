import Foundation

// MARK: - Error

public enum ChecklistTemplateLoaderError: LocalizedError {
    case fileNotFound(region: RegionProfile)
    case decodingFailed(region: RegionProfile, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let region):
            return "Checklist template file not found for region '\(region.rawValue)'. " +
                   "Expected bundle resource: \(ChecklistTemplateLoader.bundleFilename(for: region)).json"
        case .decodingFailed(let region, let underlying):
            return "Failed to decode checklist template for region '\(region.rawValue)': \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Loader

/// Loads checklist templates from JSON files bundled with the package.
/// Inject a custom `bundle` in unit tests to supply fixture JSON without touching the module bundle.
public struct ChecklistTemplateLoader {

    let bundle: Bundle

    // Default resolves to the package's own resource bundle (Bundle.module).
    // Bundle.module is internal to the module, so it cannot appear in a public
    // initializer's default-argument value — pass nil to get it, or inject a
    // fixture bundle in tests.
    public init(bundle: Bundle? = nil) {
        self.bundle = bundle ?? .module
    }

    /// Loads all templates for the given region. Korea stays single-template (auto-selectable
    /// by the caller). `.global` now resolves the two US Federal templates (WO LEGAL-3B) instead
    /// of the retired single General/Construction-mixed template — `checklist_global.json` itself
    /// is untouched on disk and still independently decodable (see `loadTemplate(filename:region:)`)
    /// so any past `Inspection.templateId` referencing it keeps resolving its category/item
    /// titleKeys through `Localizable.strings` unchanged; it just no longer appears in the
    /// user-facing template picker.
    /// nonisolated: file I/O with no main-actor dependency; callable from any actor context.
    public nonisolated func load(for region: RegionProfile) throws -> [ChecklistTemplate] {
        switch region {
        case .korea:
            return [try loadTemplate(filename: Self.bundleFilename(for: region), region: region)]
        case .global:
            return try Self.usFederalTemplateFilenames.map { try loadTemplate(filename: $0, region: region) }
        }
    }

    /// Decodes a single template JSON file by its bundle filename (without extension). Exposed
    /// publicly — not just used internally by `load(for:)` — so a filename outside the current
    /// per-region selection list, e.g. the retired `checklist_global.json`, can still be
    /// decode-verified directly (WO LEGAL-3B legacy-record compatibility test).
    public nonisolated func loadTemplate(filename: String, region: RegionProfile) throws -> ChecklistTemplate {
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            throw ChecklistTemplateLoaderError.fileNotFound(region: region)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ChecklistTemplateLoaderError.fileNotFound(region: region)
        }

        do {
            return try JSONDecoder().decode(ChecklistTemplate.self, from: data)
        } catch {
            throw ChecklistTemplateLoaderError.decodingFailed(region: region, underlying: error)
        }
    }

    // MARK: - Internal

    /// Maps a RegionProfile to its legacy single-file JSON filename (without extension). Korea
    /// still resolves through this in `load(for:)`; the `.global` case continues to correctly
    /// name the retired `checklist_global.json` file (still present, still decodable) even though
    /// `load(for: .global)` no longer resolves through it — kept, not repurposed (WO LEGAL-3B).
    public nonisolated static func bundleFilename(for region: RegionProfile) -> String {
        switch region {
        case .korea:  return "checklist_korea"
        case .global: return "checklist_global"
        }
    }

    /// The two US Federal template filenames `.global` now resolves, in fixed display order
    /// (General Industry, then Construction) — WO LEGAL-3B §A.
    public nonisolated static let usFederalTemplateFilenames = [
        "checklist_us_federal_general_industry",
        "checklist_us_federal_construction"
    ]
}
