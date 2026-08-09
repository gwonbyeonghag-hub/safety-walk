import Testing
import Foundation
import SafetyWalkCore

// MARK: - bundleFilename mapping
// Pure string-mapping tests — no I/O, always fast and stable.

@Suite("ChecklistTemplateLoader — filename mapping")
struct ChecklistTemplateLoaderFilenameTests {

    @Test func koreaFilenameIsCorrect() {
        #expect(ChecklistTemplateLoader.bundleFilename(for: .korea) == "checklist_korea")
    }

    @Test func globalFilenameIsCorrect() {
        #expect(ChecklistTemplateLoader.bundleFilename(for: .global) == "checklist_global")
    }
}

// MARK: - Happy path: loading from the module bundle
// The default ChecklistTemplateLoader() resolves Bundle.module (SafetyWalkCore's
// resource bundle), which contains the JSON template files processed in.

@Suite("ChecklistTemplateLoader — load Korea template")
struct ChecklistTemplateLoaderKoreaTests {

    let loader = ChecklistTemplateLoader()   // uses Bundle.module

    @Test func koreaTemplateReturnsOneTemplate() throws {
        let templates = try loader.load(for: .korea)
        #expect(templates.count == 1)
    }

    @Test func koreaTemplateHasCorrectRegionProfile() throws {
        let template = try loader.load(for: .korea)[0]
        #expect(template.regionProfile == .korea)
    }

    @Test func koreaTemplateIdIsNonEmpty() throws {
        let template = try loader.load(for: .korea)[0]
        #expect(!template.id.isEmpty)
    }

    @Test func koreaTemplateHasFourteenCategories() throws {
        let template = try loader.load(for: .korea)[0]
        #expect(template.categories.count == 14)
    }

    @Test func koreaTemplateHasFortyTwoItems() throws {
        let template = try loader.load(for: .korea)[0]
        let total = template.categories.reduce(0) { $0 + $1.items.count }
        #expect(total == 42)
    }

    @Test func koreaTemplateCategoryTitleKeysAreNonEmpty() throws {
        let template = try loader.load(for: .korea)[0]
        for category in template.categories {
            #expect(!category.titleKey.isEmpty,
                    "Category '\(category.id)' has an empty titleKey")
        }
    }

    @Test func koreaTemplateCategoryTitleKeysUseCorrectNamespace() throws {
        let template = try loader.load(for: .korea)[0]
        for category in template.categories {
            #expect(category.titleKey.hasPrefix("checklist.category."),
                    "Category '\(category.id)' titleKey '\(category.titleKey)' must start with checklist.category.*")
        }
    }

    @Test func koreaTemplateItemTitleKeysAreNonEmpty() throws {
        let template = try loader.load(for: .korea)[0]
        for category in template.categories {
            for item in category.items {
                #expect(!item.titleKey.isEmpty,
                        "Item '\(item.id)' in category '\(category.id)' has an empty titleKey")
            }
        }
    }

    @Test func koreaTemplateItemTitleKeysUseCorrectNamespace() throws {
        let template = try loader.load(for: .korea)[0]
        for category in template.categories {
            for item in category.items {
                #expect(item.titleKey.hasPrefix("checklist.item."),
                        "Item '\(item.id)' titleKey '\(item.titleKey)' must start with checklist.item.*")
            }
        }
    }

    @Test func koreaTemplateItemIdsAreUnique() throws {
        let template = try loader.load(for: .korea)[0]
        let allIds = template.categories.flatMap { $0.items.map(\.id) }
        #expect(Set(allIds).count == allIds.count, "Duplicate item IDs found in Korea template")
    }
}

// MARK: - .global — US Federal templates (WO LEGAL-3B)
// `.global` now resolves the two versioned US Federal templates (General Industry /
// Construction) instead of the retired single mixed `checklist_global.json`. Structural
// checks (non-empty/namespaced titleKeys, unique item ids) run against BOTH.

@Suite("ChecklistTemplateLoader — load Global template")
struct ChecklistTemplateLoaderGlobalTests {

    let loader = ChecklistTemplateLoader()

    @Test func globalReturnsExactlyTwoTemplates() throws {
        let templates = try loader.load(for: .global)
        #expect(templates.count == 2)
    }

    @Test func globalTemplatesHaveCorrectRegionProfile() throws {
        for template in try loader.load(for: .global) {
            #expect(template.regionProfile == .global)
        }
    }

    @Test func globalTemplateIdsAreDistinct() throws {
        let templates = try loader.load(for: .global)
        let ids = templates.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Set(ids) == ["us-federal-general-industry-v1", "us-federal-construction-v1"])
    }

    @Test func globalTemplateIndustryScopesAreDistinct() throws {
        let templates = try loader.load(for: .global)
        let scopes = templates.map(\.industryScope)
        #expect(scopes.contains(.general))
        #expect(scopes.contains(.construction))
        #expect(Set(templates.map { $0.industryScope }).count == 2)
    }

    @Test func legacyGlobalTemplateIsExcludedFromSelectionList() throws {
        let templates = try loader.load(for: .global)
        #expect(!templates.contains { $0.id == "global-general-v1" })
    }

    @Test func legacyGlobalJSONStillDecodesDirectly() throws {
        // checklist_global.json is retired from the picker but must remain untouched and
        // decodable — past `Inspection.templateId` values still reference it (§A).
        let legacy = try loader.loadTemplate(filename: "checklist_global", region: .global)
        #expect(legacy.id == "global-general-v1")
        #expect(legacy.industryScope == nil)   // pre-existing JSON never had this field
        #expect(legacy.sourceCatalog == nil)
    }

    @Test func globalTemplateCategoryTitleKeysAreNonEmptyAndNamespaced() throws {
        for template in try loader.load(for: .global) {
            for category in template.categories {
                #expect(!category.titleKey.isEmpty, "Category '\(category.id)' has an empty titleKey")
                #expect(category.titleKey.hasPrefix("checklist.category."),
                        "Category '\(category.id)' titleKey '\(category.titleKey)' must start with checklist.category.*")
            }
        }
    }

    @Test func globalTemplateItemTitleKeysAreNonEmptyAndNamespaced() throws {
        for template in try loader.load(for: .global) {
            for category in template.categories {
                for item in category.items {
                    #expect(!item.titleKey.isEmpty, "Item '\(item.id)' has an empty titleKey")
                    #expect(item.titleKey.hasPrefix("checklist.item."),
                            "Item '\(item.id)' titleKey '\(item.titleKey)' must start with checklist.item.*")
                }
            }
        }
    }

    @Test func globalTemplateItemIdsAreUniqueWithinEachTemplate() throws {
        for template in try loader.load(for: .global) {
            let allIds = template.categories.flatMap { $0.items.map(\.id) }
            #expect(Set(allIds).count == allIds.count, "Duplicate item IDs found in '\(template.id)'")
        }
    }
}

// MARK: - US Federal template metadata (WO LEGAL-3B §C) — machine-verifiable source coverage

@Suite("ChecklistTemplateLoader — US Federal template source metadata (WO LEGAL-3B)")
struct ChecklistTemplateLoaderUSFederalSourceTests {

    let loader = ChecklistTemplateLoader()

    @Test func requiredMetadataIsPresent() throws {
        for template in try loader.load(for: .global) {
            #expect(template.version != nil, "'\(template.id)' missing version")
            #expect(template.industryScope != nil, "'\(template.id)' missing industryScope")
            #expect(template.reviewedOn != nil, "'\(template.id)' missing reviewedOn")
            #expect(template.reviewedOn == "2026-08-09")
            #expect(template.sourceCatalog != nil, "'\(template.id)' missing sourceCatalog")
        }
    }

    @Test func everyItemHasNonEmptySourceIds() throws {
        for template in try loader.load(for: .global) {
            for category in template.categories {
                for item in category.items {
                    #expect(item.sourceIds?.isEmpty == false,
                            "'\(template.id)' item '\(item.id)' has no sourceIds")
                }
            }
        }
    }

    @Test func everyItemSourceIdExistsInTheTemplatesCatalog() throws {
        for template in try loader.load(for: .global) {
            let catalogIds = Set((template.sourceCatalog ?? []).map(\.id))
            for category in template.categories {
                for item in category.items {
                    for sourceId in item.sourceIds ?? [] {
                        #expect(catalogIds.contains(sourceId),
                                "'\(template.id)' item '\(item.id)' cites unknown source '\(sourceId)'")
                    }
                }
            }
        }
    }

    @Test func noOrphanOrDuplicateCatalogEntries() throws {
        for template in try loader.load(for: .global) {
            let catalog = template.sourceCatalog ?? []
            let catalogIds = catalog.map(\.id)
            #expect(Set(catalogIds).count == catalogIds.count,
                    "'\(template.id)' has duplicate sourceCatalog ids")

            let usedIds = Set(template.categories.flatMap { $0.items.flatMap { $0.sourceIds ?? [] } })
            let unused = Set(catalogIds).subtracting(usedIds)
            #expect(unused.isEmpty, "'\(template.id)' has orphan (unused) sourceCatalog entries: \(unused)")
        }
    }

    @Test func sourceURLsAreOnTheApprovedOfficialDomain() throws {
        for template in try loader.load(for: .global) {
            for source in template.sourceCatalog ?? [] {
                #expect(source.url.hasPrefix("https://www.osha.gov/"),
                        "'\(template.id)' source '\(source.id)' url is not an official osha.gov page: \(source.url)")
            }
        }
    }

    /// The core structural guard against the WO's named defect: a checklist item citing General
    /// Industry (29 CFR 1910) and Construction (29 CFR 1926) thresholds in the same place. Since
    /// each template now owns an independent sourceCatalog, this asserts no cross-standard leak —
    /// the General Industry template only ever cites 1910.*, Construction only ever cites 1926.*.
    @Test func generalIndustryAndConstructionCatalogsNeverCrossCiteEachOther() throws {
        let templates = try loader.load(for: .global)
        let general = try #require(templates.first { $0.industryScope == .general })
        let construction = try #require(templates.first { $0.industryScope == .construction })

        for source in general.sourceCatalog ?? [] {
            #expect(source.standardNumber.contains("1910"),
                    "General Industry source '\(source.id)' is not a 1910 citation: \(source.standardNumber)")
            #expect(!source.standardNumber.contains("1926"),
                    "General Industry source '\(source.id)' unexpectedly cites 1926: \(source.standardNumber)")
        }
        for source in construction.sourceCatalog ?? [] {
            #expect(source.standardNumber.contains("1926"),
                    "Construction source '\(source.id)' is not a 1926 citation: \(source.standardNumber)")
            #expect(!source.standardNumber.contains("1910"),
                    "Construction source '\(source.id)' unexpectedly cites 1910: \(source.standardNumber)")
        }
    }
}

// MARK: - ChecklistTemplatePolicy (WO LEGAL-3B §E)

@Suite("ChecklistTemplatePolicy — templateId → US Federal scope (WO LEGAL-3B)")
struct ChecklistTemplatePolicyTests {

    @Test func generalIndustryTemplateResolvesGeneralScope() {
        #expect(ChecklistTemplatePolicy.usFederalScope(forTemplateId: "us-federal-general-industry-v1") == .general)
    }

    @Test func constructionTemplateResolvesConstructionScope() {
        #expect(ChecklistTemplatePolicy.usFederalScope(forTemplateId: "us-federal-construction-v1") == .construction)
    }

    @Test func legacyGlobalTemplateResolvesNoScope() {
        #expect(ChecklistTemplatePolicy.usFederalScope(forTemplateId: "global-general-v1") == nil)
    }

    @Test func koreaTemplateResolvesNoScope() {
        #expect(ChecklistTemplatePolicy.usFederalScope(forTemplateId: "korea-standard-v1") == nil)
    }

    @Test func unknownTemplateIdResolvesNoScope() {
        #expect(ChecklistTemplatePolicy.usFederalScope(forTemplateId: "") == nil)
        #expect(ChecklistTemplatePolicy.usFederalScope(forTemplateId: "not-a-real-template") == nil)
    }

    @Test func showsFederalNoticeOnlyForUSFederalTemplates() {
        #expect(ChecklistTemplatePolicy.showsFederalNotice(forTemplateId: "us-federal-general-industry-v1"))
        #expect(ChecklistTemplatePolicy.showsFederalNotice(forTemplateId: "us-federal-construction-v1"))
        #expect(!ChecklistTemplatePolicy.showsFederalNotice(forTemplateId: "global-general-v1"))
        #expect(!ChecklistTemplatePolicy.showsFederalNotice(forTemplateId: "korea-standard-v1"))
    }
}

// MARK: - Error paths: missing file and malformed JSON
// Uses a fixture bundle created in a temporary directory.
// Bundle.url(forResource:withExtension:) looks at the bundle root for flat-directory bundles,
// so files placed directly in the .bundle directory are found correctly.

@Suite("ChecklistTemplateLoader — error paths")
struct ChecklistTemplateLoaderErrorTests {

    // MARK: Missing file

    @Test func missingFileThrowsFileNotFoundError() throws {
        let (bundle, cleanup) = try Self.makeEmptyBundle()
        defer { cleanup() }

        let loader = ChecklistTemplateLoader(bundle: bundle)

        do {
            _ = try loader.load(for: .korea)
            Issue.record("Expected ChecklistTemplateLoaderError.fileNotFound but load succeeded.")
        } catch ChecklistTemplateLoaderError.fileNotFound {
            // correct — test passes
        } catch {
            Issue.record("Wrong error: expected .fileNotFound, got \(error)")
        }
    }

    @Test func missingFileErrorMessageContainsRegionName() throws {
        let (bundle, cleanup) = try Self.makeEmptyBundle()
        defer { cleanup() }

        let loader = ChecklistTemplateLoader(bundle: bundle)

        do {
            _ = try loader.load(for: .global)
            Issue.record("Expected error to be thrown.")
        } catch let error as ChecklistTemplateLoaderError {
            let description = error.errorDescription ?? ""
            #expect(description.contains("global"),
                    "Error description should mention the region. Got: \(description)")
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: Malformed JSON

    @Test func malformedJSONThrowsDecodingFailedError() throws {
        let (bundle, cleanup) = try Self.makeBundleWithJSON(
            "{ this is not valid json }",
            filename: "checklist_korea.json"
        )
        defer { cleanup() }

        let loader = ChecklistTemplateLoader(bundle: bundle)

        do {
            _ = try loader.load(for: .korea)
            Issue.record("Expected ChecklistTemplateLoaderError.decodingFailed but load succeeded.")
        } catch ChecklistTemplateLoaderError.decodingFailed {
            // correct — test passes
        } catch {
            Issue.record("Wrong error: expected .decodingFailed, got \(error)")
        }
    }

    @Test func missingRequiredKeyThrowsDecodingFailedError() throws {
        // Valid JSON but missing the required "categories" key
        let incompleteJSON = """
        {
          "id": "test-template",
          "regionProfile": "korea",
          "name": "Test"
        }
        """
        let (bundle, cleanup) = try Self.makeBundleWithJSON(
            incompleteJSON,
            filename: "checklist_korea.json"
        )
        defer { cleanup() }

        let loader = ChecklistTemplateLoader(bundle: bundle)

        do {
            _ = try loader.load(for: .korea)
            Issue.record("Expected .decodingFailed for JSON missing required key.")
        } catch ChecklistTemplateLoaderError.decodingFailed {
            // correct — test passes
        } catch {
            Issue.record("Wrong error: expected .decodingFailed, got \(error)")
        }
    }

    // MARK: Fixture helpers

    private static func makeEmptyBundle() throws -> (Bundle, cleanup: () -> Void) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SafetyWalkTest-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let bundle = Bundle(url: url)!
        return (bundle, { try? FileManager.default.removeItem(at: url) })
    }

    private static func makeBundleWithJSON(
        _ json: String,
        filename: String
    ) throws -> (Bundle, cleanup: () -> Void) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SafetyWalkTest-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try json.write(to: url.appendingPathComponent(filename), atomically: true, encoding: .utf8)
        let bundle = Bundle(url: url)!
        return (bundle, { try? FileManager.default.removeItem(at: url) })
    }
}
