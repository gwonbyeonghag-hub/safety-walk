import Foundation
import SwiftData
import Observation

@Observable
final class StartInspectionViewModel {

    // MARK: - Step state

    var selectedSite: Site?
    var selectedArea: Area?
    var areaFreeText: String = ""
    var skipArea: Bool = false

    // Reset scope when the user changes their template choice (e.g. going Back from Scope
    // to Template and picking a different region). Without this, selectedCategoryKeys
    // could carry over keys that don't exist in the new template, producing misleading
    // summary counts and a falsely-enabled Begin button.
    // We compare by `id` so re-assignment of the same template (e.g. re-load) doesn't
    // clobber the user's in-progress edits.
    var selectedTemplate: ChecklistTemplate? {
        didSet {
            if oldValue?.id != selectedTemplate?.id {
                selectedCategoryKeys = []
            }
        }
    }
    var templates: [ChecklistTemplate] = []

    // Category titleKeys included in this inspection. Empty means scope-not-yet-chosen
    // on the scope screen; the Begin button stays disabled until at least one is selected.
    // An "excluded" category is simply not in this set — no ChecklistItem is created for it.
    // This is distinct from N/A (an included item the inspector marked as not applicable).
    var selectedCategoryKeys: Set<String> = []

    /// Category titleKeys applied by the "Recommended Defaults" button.
    /// Keys absent from the active template are filtered out at apply time.
    static let recommendedDefaultCategoryKeys: Set<String> = [
        "checklist.category.commonSafety",
        "checklist.category.housekeeping",
        "checklist.category.ppe",
        "checklist.category.fire",
        "checklist.category.emergencyResponse"
    ]

    // MARK: - Derived: navigation guards

    var canProceedFromSite: Bool { selectedSite != nil }
    var canProceedFromTemplate: Bool { selectedTemplate != nil }
    // Defence in depth: even though selectedTemplate's didSet clears selectedCategoryKeys
    // on template change, the gate also checks the effective intersection so a stray
    // key from any future code path cannot enable Begin with 0 items generated.
    var canBeginInspection: Bool {
        selectedSite != nil && selectedTemplate != nil && effectiveSelectedCount > 0
    }

    /// Count of selectedCategoryKeys that actually exist in the active template.
    /// Use this for any UI summary or guard — `selectedCategoryKeys.count` alone
    /// could be misleading if the template was swapped while the set was non-empty.
    var effectiveSelectedCount: Int {
        guard let template = selectedTemplate else { return 0 }
        let templateKeys = Set(template.categories.map(\.titleKey))
        return selectedCategoryKeys.intersection(templateKeys).count
    }

    // MARK: - Derived: resolved area for Inspection creation

    var resolvedAreaName: String? {
        if skipArea { return nil }
        if let area = selectedArea { return area.name }
        let trimmed = areaFreeText.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    var resolvedAreaId: UUID? {
        skipArea ? nil : selectedArea?.id
    }

    // MARK: - Derived: scope summary

    /// Total items that will be generated for the currently selected scope.
    var generatedItemCount: Int {
        guard let template = selectedTemplate else { return 0 }
        return template.categories
            .filter { selectedCategoryKeys.contains($0.titleKey) }
            .reduce(0) { $0 + $1.items.count }
    }

    // MARK: - Scope mutations

    func isCategorySelected(_ titleKey: String) -> Bool {
        selectedCategoryKeys.contains(titleKey)
    }

    func toggleCategory(_ titleKey: String) {
        if selectedCategoryKeys.contains(titleKey) {
            selectedCategoryKeys.remove(titleKey)
        } else {
            selectedCategoryKeys.insert(titleKey)
        }
    }

    func selectAllCategories() {
        guard let template = selectedTemplate else { return }
        selectedCategoryKeys = Set(template.categories.map(\.titleKey))
    }

    func clearCategories() {
        selectedCategoryKeys = []
    }

    /// Applies the static recommended defaults, intersected with the active template.
    /// Defaults not present in the template are silently ignored.
    func applyRecommendedCategoryDefaults() {
        guard let template = selectedTemplate else {
            selectedCategoryKeys = []
            return
        }
        let templateKeys = Set(template.categories.map(\.titleKey))
        selectedCategoryKeys = Self.recommendedDefaultCategoryKeys.intersection(templateKeys)
    }

    // MARK: - Template loading

    /// Loads templates for all region profiles and pre-selects the one matching
    /// the stored RegionProfileStore value. Called from TemplateSelectionView.onAppear.
    func loadTemplates() {
        let loader = ChecklistTemplateLoader()
        var loaded: [ChecklistTemplate] = []
        for region in RegionProfile.allCases {
            loaded += (try? loader.load(for: region)) ?? []
        }
        templates = loaded

        let currentRegion = RegionProfileStore.get()
        selectedTemplate = loaded.first { $0.regionProfile == currentRegion } ?? loaded.first
    }

    // MARK: - Inspection creation

    /// Creates an Inspection and one ChecklistItem per template item that falls
    /// inside the selected scope. Categories not in `selectedCategoryKeys` are
    /// fully excluded — no ChecklistItem records are created for them. The
    /// completion logic in ChecklistView then operates only on generated items.
    ///
    /// Stores localization keys (titleKey / category titleKey) so the UI can
    /// resolve them through the active language bundle (via `L(_:)`) at display
    /// time — labels stay correct after a language switch without re-creating
    /// inspection records.
    func createInspection(context: ModelContext) {
        guard let site = selectedSite, let template = selectedTemplate else { return }

        let inspectorName = UserDefaults.standard.string(
            forKey: "com.safetywalk.inspectorName"
        ) ?? ""

        let inspection = Inspection(
            siteId: site.id,
            siteName: site.name,
            areaId: resolvedAreaId,
            areaName: resolvedAreaName,
            inspectorName: inspectorName,
            templateId: template.id
        )
        context.insert(inspection)

        var sortOrder = 0
        for category in template.categories where selectedCategoryKeys.contains(category.titleKey) {
            for item in category.items {
                let row = ChecklistItem(
                    inspectionId: inspection.id,
                    templateItemId: item.id,
                    title: item.titleKey,
                    category: category.titleKey,
                    sortOrder: sortOrder
                )
                context.insert(row)
                inspection.items.append(row)
                sortOrder += 1
            }
        }

        try? context.save()
    }
}
