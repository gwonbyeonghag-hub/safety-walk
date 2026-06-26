import SwiftUI
import SafetyWalkCore
import SwiftData
import PhotosUI

/// Presented as a sheet to create a new Hazard record.
/// Pass a `checklistItem` when launching from a Fail row so the link is written back.
/// `inspection` is nil for a standalone hazard registered outside any inspection
/// (PRD F-04 / F-01); in that case the user picks a site from `availableSites`.
struct HazardRegistrationView: View {

    /// Non-nil when launched from a Fail checklist row (in-inspection). Nil = standalone.
    var inspection: Inspection? = nil
    var checklistItem: ChecklistItem? = nil
    /// Sites a standalone hazard can attach to. Passed in by the presenter (Hazards tab)
    /// so this shared sheet never owns a `@Query`. Empty when launched in-inspection.
    var availableSites: [Site] = []

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Photo
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    // Form fields
    @State private var location: String = ""
    @State private var hazardType: HazardType = .general
    @State private var riskLevel: RiskLevel = .medium
    @State private var hazardDescription: String = ""
    @State private var correctiveStatus: CorrectiveActionStatus = .notStarted

    // Standalone-only: which site the hazard attaches to (nil in-inspection).
    @State private var selectedSite: Site? = nil

    // Photo error surfacing (5-3) — sheet stays open on failure.
    @State private var showPhotoLoadFailed = false
    @State private var showPhotoSaveFailed = false

    private var canSave: Bool {
        selectedImage != nil
            && resolvedSiteId != nil
            && !location.trimmingCharacters(in: .whitespaces).isEmpty
            && !hazardDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Site the hazard attaches to: the inspection's site in-inspection, or the
    /// user-selected site when standalone. Drives `canSave` and `save()`.
    private var resolvedSiteId: UUID? {
        inspection?.siteId ?? selectedSite?.id
    }

    var body: some View {
        NavigationStack {
            Form {
                if inspection == nil { siteSection }
                photoSection
                locationSection
                typeSection
                riskSection
                descriptionSection
                statusSection
            }
            .navigationTitle(LocalizationKey.hazardRegistrationTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonSave.localized) { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: setupDefaults)
            .task(id: pickerItem) { await loadSelectedPhoto() }
            .alert(LocalizationKey.errorPhotoLoadFailed.localized,
                   isPresented: $showPhotoLoadFailed) {
                Button(LocalizationKey.commonConfirm.localized) {}
            }
            .alert(LocalizationKey.errorPhotoSaveFailed.localized,
                   isPresented: $showPhotoSaveFailed) {
                Button(LocalizationKey.commonConfirm.localized) {}
            }
        }
    }

    // MARK: - Form sections

    /// Standalone only: choose which site this hazard belongs to. A single saved site
    /// is auto-selected in `setupDefaults`. No saved sites → a hint (cannot save).
    @ViewBuilder
    private var siteSection: some View {
        Section(LocalizationKey.inspectionSelectSite.localized) {
            if availableSites.isEmpty {
                Text(LocalizationKey.hazardNoSitesForStandalone.localized)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Picker(LocalizationKey.inspectionSelectSite.localized, selection: $selectedSite) {
                    ForEach(availableSites) { site in
                        Text(site.name).tag(site as Site?)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var photoSection: some View {
        Section(LocalizationKey.hazardPhoto.localized) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    selectedImage == nil
                        ? LocalizationKey.checklistAttachPhoto.localized
                        : LocalizationKey.checklistReplacePhoto.localized,
                    systemImage: selectedImage == nil ? "camera" : "arrow.triangle.2.circlepath"
                )
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }

            if selectedImage == nil {
                Text(LocalizationKey.hazardPhotoRequired.localized)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var locationSection: some View {
        Section(LocalizationKey.hazardLocation.localized) {
            TextField(
                LocalizationKey.hazardLocation.localized,
                text: $location
            )
        }
    }

    private var typeSection: some View {
        Section(LocalizationKey.hazardType.localized) {
            Picker(LocalizationKey.hazardType.localized, selection: $hazardType) {
                ForEach(HazardType.allCases, id: \.self) { type in
                    Text(typeLabel(type)).tag(type)
                }
            }
            .labelsHidden()
        }
    }

    private var riskSection: some View {
        Section(LocalizationKey.hazardRiskLevel.localized) {
            HStack(spacing: 1) {
                riskButton(.low)
                riskButton(.medium)
                riskButton(.high)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var descriptionSection: some View {
        Section(LocalizationKey.hazardDescription.localized) {
            TextField(
                LocalizationKey.hazardDescriptionPlaceholder.localized,
                text: $hazardDescription,
                axis: .vertical
            )
            .lineLimit(3...6)
        }
    }

    private var statusSection: some View {
        Section(LocalizationKey.hazardCorrectiveStatus.localized) {
            Picker(LocalizationKey.hazardCorrectiveStatus.localized, selection: $correctiveStatus) {
                ForEach(CorrectiveActionStatus.allCases, id: \.self) { status in
                    Text(statusLabel(status)).tag(status)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Risk buttons

    @ViewBuilder
    private func riskButton(_ level: RiskLevel) -> some View {
        let isSelected = riskLevel == level
        Button { riskLevel = level } label: {
            Text(riskLabel(level))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(isSelected ? .white : riskColor(level))
                .background(isSelected ? riskColor(level) : riskColor(level).opacity(0.10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Helpers

    private var defaultLocation: String {
        if let inspection {
            if let area = inspection.areaName, !area.isEmpty {
                return "\(inspection.siteName) - \(area)"
            }
            return inspection.siteName
        }
        // Standalone: seed the editable location from the chosen site's name.
        return selectedSite?.name ?? ""
    }

    /// Auto-select a single saved site (standalone) and seed the editable location.
    private func setupDefaults() {
        if inspection == nil, selectedSite == nil, availableSites.count == 1 {
            selectedSite = availableSites.first
        }
        location = defaultLocation
    }

    private func typeLabel(_ type: HazardType) -> String {
        switch type {
        case .fallRisk:   return LocalizationKey.hazardTypeFallRisk.localized
        case .electrical: return LocalizationKey.hazardTypeElectrical.localized
        case .fire:       return LocalizationKey.hazardTypeFire.localized
        case .chemical:   return LocalizationKey.hazardTypeChemical.localized
        case .general:    return LocalizationKey.hazardTypeGeneral.localized
        case .other:      return LocalizationKey.hazardTypeOther.localized
        }
    }

    private func riskLabel(_ level: RiskLevel) -> String {
        switch level {
        case .low:    return LocalizationKey.riskLow.localized
        case .medium: return LocalizationKey.riskMedium.localized
        case .high:   return LocalizationKey.riskHigh.localized
        }
    }

    private func riskColor(_ level: RiskLevel) -> Color {
        switch level {
        case .low:    return .riskLow
        case .medium: return .orange
        case .high:   return .red
        }
    }

    private func statusLabel(_ status: CorrectiveActionStatus) -> String {
        switch status {
        case .notStarted: return LocalizationKey.statusNotStarted.localized
        case .inProgress: return LocalizationKey.statusInProgress.localized
        case .completed:  return LocalizationKey.statusCompleted.localized
        }
    }

    // MARK: - Photo loading

    private func loadSelectedPhoto() async {
        guard let selected = pickerItem else { return }
        let loadedData: Data?
        do {
            loadedData = try await selected.loadTransferable(type: Data.self)
        } catch {
            pickerItem = nil
            showPhotoLoadFailed = true
            return
        }
        guard let data = loadedData, let image = UIImage(data: data) else {
            pickerItem = nil
            showPhotoLoadFailed = true
            return
        }
        selectedImage = image
        pickerItem = nil
    }

    // MARK: - Save

    private func save() {
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = hazardDescription.trimmingCharacters(in: .whitespaces)
        guard let image = selectedImage,
              let siteId = resolvedSiteId,
              !trimmedLocation.isEmpty,
              !trimmedDescription.isEmpty else { return }

        // Photo is saved to disk only here so cancelling leaves no orphaned files.
        // On failure, surface a localized alert and keep the sheet open so the user
        // can retry or pick a different photo. The Hazard record is NOT created.
        let photoPath: String
        do {
            photoPath = try PhotoStorageService().save(image)
        } catch {
            showPhotoSaveFailed = true
            return
        }

        let hazard = Hazard(
            siteId: siteId,
            location: trimmedLocation,
            type: hazardType,
            riskLevel: riskLevel,
            hazardDescription: trimmedDescription,
            photoPath: photoPath,
            inspectionId: inspection?.id
        )
        modelContext.insert(hazard)
        // Link to the parent inspection only when launched in-inspection.
        inspection?.hazards.append(hazard)

        // Back-link to the checklist item that triggered this registration.
        checklistItem?.linkedHazardId = hazard.id

        try? modelContext.save()
        dismiss()
    }
}
