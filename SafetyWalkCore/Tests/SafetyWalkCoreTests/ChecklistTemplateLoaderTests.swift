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

@Suite("ChecklistTemplateLoader — load Global template")
struct ChecklistTemplateLoaderGlobalTests {

    let loader = ChecklistTemplateLoader()

    @Test func globalTemplateReturnsOneTemplate() throws {
        let templates = try loader.load(for: .global)
        #expect(templates.count == 1)
    }

    @Test func globalTemplateHasCorrectRegionProfile() throws {
        let template = try loader.load(for: .global)[0]
        #expect(template.regionProfile == .global)
    }

    @Test func globalTemplateIdIsNonEmpty() throws {
        let template = try loader.load(for: .global)[0]
        #expect(!template.id.isEmpty)
    }

    @Test func globalTemplateHasSeventeenCategories() throws {
        let template = try loader.load(for: .global)[0]
        #expect(template.categories.count == 17)
    }

    @Test func globalTemplateHasFiftyOneItems() throws {
        let template = try loader.load(for: .global)[0]
        let total = template.categories.reduce(0) { $0 + $1.items.count }
        #expect(total == 51)
    }

    @Test func globalTemplateCategoryTitleKeysAreNonEmpty() throws {
        let template = try loader.load(for: .global)[0]
        for category in template.categories {
            #expect(!category.titleKey.isEmpty,
                    "Category '\(category.id)' has an empty titleKey")
        }
    }

    @Test func globalTemplateCategoryTitleKeysUseCorrectNamespace() throws {
        let template = try loader.load(for: .global)[0]
        for category in template.categories {
            #expect(category.titleKey.hasPrefix("checklist.category."),
                    "Category '\(category.id)' titleKey '\(category.titleKey)' must start with checklist.category.*")
        }
    }

    @Test func globalTemplateItemTitleKeysAreNonEmpty() throws {
        let template = try loader.load(for: .global)[0]
        for category in template.categories {
            for item in category.items {
                #expect(!item.titleKey.isEmpty,
                        "Item '\(item.id)' has an empty titleKey")
            }
        }
    }

    @Test func globalTemplateItemTitleKeysUseCorrectNamespace() throws {
        let template = try loader.load(for: .global)[0]
        for category in template.categories {
            for item in category.items {
                #expect(item.titleKey.hasPrefix("checklist.item."),
                        "Item '\(item.id)' titleKey '\(item.titleKey)' must start with checklist.item.*")
            }
        }
    }

    @Test func globalTemplateItemIdsAreUnique() throws {
        let template = try loader.load(for: .global)[0]
        let allIds = template.categories.flatMap { $0.items.map(\.id) }
        #expect(Set(allIds).count == allIds.count, "Duplicate item IDs found in Global template")
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
