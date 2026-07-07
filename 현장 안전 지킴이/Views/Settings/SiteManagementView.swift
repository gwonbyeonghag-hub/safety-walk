import SwiftUI
import SafetyWalkCore
import SwiftData

/// Settings → Manage Sites
///
/// Root of the management flow (Settings tab depth 1). Owns the SwiftData @Query
/// for Site, Inspection, and Hazard so it can compute referenced ids and gate
/// deletions. Pushes `SiteDetailManagementView` for per-site editing — that
/// detail view owns no @Query (see /navigation-qa Rule A on depth-2+ @Query).
struct SiteManagementView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Site.name) private var sites: [Site]
    @Query private var inspections: [Inspection]
    @Query private var hazards: [Hazard]

    @State private var isAddingSite = false
    @State private var newSiteName = ""
    @State private var newSiteAddress = ""

    @State private var pendingDeleteSite: Site?
    @State private var showDeleteConfirm = false
    @State private var showDeleteBlocked = false

    // MARK: - Reference sets (deletion gates)

    private var referencedSiteIds: Set<UUID> {
        var ids: Set<UUID> = []
        for inspection in inspections { ids.insert(inspection.siteId) }
        for hazard in hazards { ids.insert(hazard.siteId) }
        return ids
    }

    private var referencedAreaIds: Set<UUID> {
        var ids: Set<UUID> = []
        for inspection in inspections {
            if let areaId = inspection.areaId { ids.insert(areaId) }
        }
        return ids
    }

    // MARK: - Body

    var body: some View {
        Form {
            sitesSection
            addSiteSection
        }
        .navigationTitle(LocalizationKey.siteManagementTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert(LocalizationKey.siteDeleteConfirmTitle.localized,
               isPresented: $showDeleteConfirm,
               presenting: pendingDeleteSite) { site in
            Button(LocalizationKey.commonDelete.localized, role: .destructive) {
                deleteSite(site)
                pendingDeleteSite = nil
            }
            Button(LocalizationKey.commonCancel.localized, role: .cancel) {
                pendingDeleteSite = nil
            }
        } message: { site in
            Text(site.name)
        }
        .alert(LocalizationKey.siteDeleteBlockedTitle.localized,
               isPresented: $showDeleteBlocked) {
            Button(LocalizationKey.commonConfirm.localized) {
                pendingDeleteSite = nil
            }
        } message: {
            Text(LocalizationKey.siteDeleteBlockedMessage.localized)
        }
    }

    // MARK: - Sites section

    @ViewBuilder
    private var sitesSection: some View {
        Section {
            if sites.isEmpty {
                Text(LocalizationKey.siteNoSites.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sites) { site in
                    NavigationLink {
                        SiteDetailManagementView(
                            site: site,
                            isSiteReferenced: referencedSiteIds.contains(site.id),
                            referencedAreaIds: referencedAreaIds
                        )
                    } label: {
                        SiteRowLabel(site: site)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            requestDelete(site)
                        } label: {
                            Label(LocalizationKey.commonDelete.localized,
                                  systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Add site section

    @ViewBuilder
    private var addSiteSection: some View {
        Section {
            if isAddingSite {
                VStack(spacing: 10) {
                    TextField(LocalizationKey.siteNamePlaceholder.localized,
                              text: $newSiteName)
                        .textFieldStyle(.roundedBorder)
                    TextField(LocalizationKey.siteAddressPlaceholder.localized,
                              text: $newSiteAddress)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 12) {
                        Button(LocalizationKey.commonCancel.localized) {
                            cancelAddSite()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button(LocalizationKey.commonSave.localized) {
                            saveSite()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(newSiteName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    isAddingSite = true
                } label: {
                    Label(LocalizationKey.siteAddSite.localized,
                          systemImage: "plus.circle")
                }
            }
        }
    }

    // MARK: - Actions

    private func requestDelete(_ site: Site) {
        pendingDeleteSite = site
        if referencedSiteIds.contains(site.id) {
            showDeleteBlocked = true
        } else {
            showDeleteConfirm = true
        }
    }

    private func deleteSite(_ site: Site) {
        // Guard: re-check at deletion time in case the SwiftData state has changed
        // between the swipe and the user tapping confirm.
        guard !referencedSiteIds.contains(site.id) else { return }
        modelContext.delete(site)
        try? modelContext.save()
    }

    private func saveSite() {
        let name = newSiteName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let address = newSiteAddress.trimmingCharacters(in: .whitespaces)
        let site = Site(name: name, address: address.isEmpty ? nil : address)
        modelContext.insert(site)
        try? modelContext.save()
        cancelAddSite()
    }

    private func cancelAddSite() {
        isAddingSite = false
        newSiteName = ""
        newSiteAddress = ""
    }
}

// MARK: - SiteRowLabel

private struct SiteRowLabel: View {
    let site: Site

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(site.name)
                .font(.body)
                .foregroundStyle(.primary)
            if let address = site.address, !address.isEmpty {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Area count with mappin icon — clarifies that the number represents
            // areas/locations under this site. VoiceOver gets a single localized
            // label like "3 areas" / "구역 3개" instead of "mappin 3".
            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.caption2)
                Text("\((site.areas ?? []).count)")
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Color(.systemGray6), in: Capsule())
            .padding(.top, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                String(format: LocalizationKey.siteAreaCountAccessibility.localized,
                       (site.areas ?? []).count)
            )
        }
        .padding(.vertical, 2)
    }
}

// MARK: - SiteDetailManagementView (depth-2 pushed view)

/// Edits a single Site: name + address (in-place via @Bindable), its Areas
/// (rename in-place, add inline, swipe-delete with reference guard), and a
/// "Delete Site" action that respects the reference gate from the parent.
///
/// Owns NO @Query — the freeze-prone pattern documented in /navigation-qa
/// Rule A. All reference info is passed in by `SiteManagementView`.
private struct SiteDetailManagementView: View {

    @Bindable var site: Site
    let isSiteReferenced: Bool
    let referencedAreaIds: Set<UUID>

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingArea = false
    @State private var newAreaName = ""

    @State private var pendingDeleteArea: Area?
    @State private var showDeleteAreaConfirm = false
    @State private var showDeleteAreaBlocked = false

    @State private var showDeleteSiteConfirm = false
    @State private var showDeleteSiteBlocked = false

    // Draft state for in-place rename. The TextFields bind to these so:
    //   (a) whitespace typed mid-word survives (no trim-per-keystroke), and
    //   (b) an empty / whitespace-only name does NOT overwrite a valid site.name —
    //       commit() preserves the last valid value.
    // Address commit converts empty/whitespace to nil so the model field clears cleanly.
    @State private var nameDraft: String = ""
    @State private var addressDraft: String = ""
    @State private var didLoadDrafts = false

    private var sortedAreas: [Area] {
        (site.areas ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Form {
            siteInfoSection
            areasSection
            addAreaSection
            deleteSiteSection
        }
        .navigationTitle(nameDraft.trimmingCharacters(in: .whitespaces).isEmpty
                         ? site.name
                         : nameDraft)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize drafts once. Subsequent re-renders should not clobber user edits.
            if !didLoadDrafts {
                nameDraft = site.name
                addressDraft = site.address ?? ""
                didLoadDrafts = true
            }
        }
        .onDisappear {
            commitSiteEdits()
        }
        .alert(LocalizationKey.areaDeleteConfirmTitle.localized,
               isPresented: $showDeleteAreaConfirm,
               presenting: pendingDeleteArea) { area in
            Button(LocalizationKey.commonDelete.localized, role: .destructive) {
                deleteArea(area)
                pendingDeleteArea = nil
            }
            Button(LocalizationKey.commonCancel.localized, role: .cancel) {
                pendingDeleteArea = nil
            }
        } message: { area in
            Text(area.name)
        }
        .alert(LocalizationKey.areaDeleteBlockedTitle.localized,
               isPresented: $showDeleteAreaBlocked) {
            Button(LocalizationKey.commonConfirm.localized) {
                pendingDeleteArea = nil
            }
        } message: {
            Text(LocalizationKey.areaDeleteBlockedMessage.localized)
        }
        .alert(LocalizationKey.siteDeleteConfirmTitle.localized,
               isPresented: $showDeleteSiteConfirm) {
            Button(LocalizationKey.commonDelete.localized, role: .destructive) {
                deleteThisSite()
            }
            Button(LocalizationKey.commonCancel.localized, role: .cancel) {}
        } message: {
            Text(site.name)
        }
        .alert(LocalizationKey.siteDeleteBlockedTitle.localized,
               isPresented: $showDeleteSiteBlocked) {
            Button(LocalizationKey.commonConfirm.localized) {}
        } message: {
            Text(LocalizationKey.siteDeleteBlockedMessage.localized)
        }
    }

    // MARK: - Sections

    private var siteInfoSection: some View {
        Section(LocalizationKey.siteManagementTitle.localized) {
            TextField(LocalizationKey.siteNamePlaceholder.localized, text: $nameDraft)
            TextField(LocalizationKey.siteAddressPlaceholder.localized, text: $addressDraft)
        }
    }

    @ViewBuilder
    private var areasSection: some View {
        Section(LocalizationKey.siteAreasSection.localized) {
            if sortedAreas.isEmpty {
                Text(LocalizationKey.areaNoAreas.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedAreas) { area in
                    AreaEditRow(area: area)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                requestDeleteArea(area)
                            } label: {
                                Label(LocalizationKey.commonDelete.localized,
                                      systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var addAreaSection: some View {
        Section {
            if isAddingArea {
                VStack(spacing: 10) {
                    TextField(LocalizationKey.areaNamePlaceholder.localized,
                              text: $newAreaName)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 12) {
                        Button(LocalizationKey.commonCancel.localized) {
                            cancelAddArea()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        Button(LocalizationKey.commonSave.localized) {
                            saveArea()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(newAreaName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    isAddingArea = true
                } label: {
                    Label(LocalizationKey.areaAddArea.localized,
                          systemImage: "plus.circle")
                }
            }
        }
    }

    @ViewBuilder
    private var deleteSiteSection: some View {
        Section {
            Button(role: .destructive) {
                requestDeleteThisSite()
            } label: {
                Label(LocalizationKey.siteDeleteSiteAction.localized,
                      systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if isSiteReferenced {
                Text(LocalizationKey.siteDeleteBlockedMessage.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Area actions

    private func requestDeleteArea(_ area: Area) {
        pendingDeleteArea = area
        if referencedAreaIds.contains(area.id) {
            showDeleteAreaBlocked = true
        } else {
            showDeleteAreaConfirm = true
        }
    }

    private func deleteArea(_ area: Area) {
        guard !referencedAreaIds.contains(area.id) else { return }
        modelContext.delete(area)
        try? modelContext.save()
    }

    private func saveArea() {
        let name = newAreaName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let area = Area(name: name, siteId: site.id)
        modelContext.insert(area)
        site.areas?.append(area)
        try? modelContext.save()
        cancelAddArea()
    }

    private func cancelAddArea() {
        isAddingArea = false
        newAreaName = ""
    }

    // MARK: - Delete this site

    private func requestDeleteThisSite() {
        if isSiteReferenced {
            showDeleteSiteBlocked = true
        } else {
            showDeleteSiteConfirm = true
        }
    }

    private func deleteThisSite() {
        guard !isSiteReferenced else { return }
        modelContext.delete(site)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Commit drafts (called from .onDisappear)

    /// Persist the in-progress name/address drafts. Empty / whitespace-only name
    /// is rejected — `site.name` keeps its last valid value. Empty / whitespace-only
    /// address clears the field to `nil`. Always saves once at the end so any
    /// in-place AreaEditRow changes also persist.
    private func commitSiteEdits() {
        let trimmedName = nameDraft.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            site.name = trimmedName
        }
        // else: preserve last valid site.name

        let trimmedAddress = addressDraft.trimmingCharacters(in: .whitespaces)
        site.address = trimmedAddress.isEmpty ? nil : trimmedAddress

        try? modelContext.save()
    }
}

// MARK: - AreaEditRow

private struct AreaEditRow: View {
    @Bindable var area: Area

    // Local draft so the user can type freely (including transient empty state)
    // without overwriting the model with an empty value. Only non-empty trimmed
    // values are committed to `area.name`. If the user leaves the field empty,
    // `area.name` keeps its last valid value (the field text may show empty
    // until next visit — acceptable trade-off; prevents bad data).
    @State private var draft: String = ""
    @State private var didLoad = false

    var body: some View {
        TextField(LocalizationKey.areaNamePlaceholder.localized, text: $draft)
            .onAppear {
                if !didLoad {
                    draft = area.name
                    didLoad = true
                }
            }
            .onChange(of: draft) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                area.name = trimmed
            }
    }
}
