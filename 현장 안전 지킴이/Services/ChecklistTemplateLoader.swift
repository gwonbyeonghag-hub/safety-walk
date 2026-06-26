import Foundation

// MARK: - Error

enum ChecklistTemplateLoaderError: LocalizedError {
    case fileNotFound(region: RegionProfile)
    case decodingFailed(region: RegionProfile, underlying: Error)

    var errorDescription: String? {
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

/// Loads checklist templates from JSON files bundled with the app.
/// One JSON file per RegionProfile; each file contains a single ChecklistTemplate object.
/// Inject a custom `bundle` in unit tests to supply fixture JSON without touching the app bundle.
struct ChecklistTemplateLoader {

    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// Loads all templates for the given region.
    /// Currently one file per region; returns a single-element array to support
    /// multiple templates per region in future without changing the call site.
    /// nonisolated: file I/O with no main-actor dependency; callable from any actor context.
    nonisolated func load(for region: RegionProfile) throws -> [ChecklistTemplate] {
        let filename = Self.bundleFilename(for: region)

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
            let template = try JSONDecoder().decode(ChecklistTemplate.self, from: data)
            return [template]
        } catch {
            throw ChecklistTemplateLoaderError.decodingFailed(region: region, underlying: error)
        }
    }

    // MARK: - Internal

    /// Maps a RegionProfile to the JSON filename (without extension) in the bundle.
    nonisolated static func bundleFilename(for region: RegionProfile) -> String {
        switch region {
        case .korea:  return "checklist_korea"
        case .global: return "checklist_global"
        }
    }
}
