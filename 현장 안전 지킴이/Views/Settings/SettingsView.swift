import SwiftUI
import SwiftData

struct SettingsView: View {

    @State private var viewModel = SettingsViewModel()
    @Environment(\.modelContext) private var modelContext

    // Local app-display preference. Same key bound by SafetyWalkApp so changes
    // re-render the whole app immediately. Not a SwiftData / account setting.
    @AppStorage("com.safetywalk.appearanceMode")
    private var appearanceMode: AppearanceMode = .system

    @State private var showReopenSetupConfirm = false
    @State private var showResetConfirm       = false
    @State private var showResetError         = false

    // Setting this false causes ContentView's AppStorage gate to show OnboardingView.
    @AppStorage("com.safetywalk.hasCompletedOnboarding")
    private var hasCompletedOnboarding = true

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            Form {
                // Inspector name
                Section(LocalizationKey.settingsInspectorName.localized) {
                    TextField(LocalizationKey.settingsInspectorName.localized,
                              text: $vm.inspectorName)
                        .autocorrectionDisabled()
                }

                // Language — a single toggle that also selects the matching content
                // (region) profile. The region picker has been folded into this control.
                Section(LocalizationKey.settingsLanguage.localized) {
                    Picker(LocalizationKey.settingsLanguage.localized,
                           selection: Binding(
                                get: { LocalizationManager.shared.language },
                                set: { LocalizationManager.shared.set($0) })) {
                        Text(LocalizationKey.languageKorean.localized)
                            .tag(AppLanguage.korean)
                        Text(LocalizationKey.languageEnglish.localized)
                            .tag(AppLanguage.english)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                appearanceSection
                reopenSetupSection
                managementSection
                dataManagementSection
                disclaimerSection
                versionSection
            }
            .navigationTitle(LocalizationKey.settingsTitle.localized)
            .alert(LocalizationKey.setupReopenConfirmTitle.localized,
                   isPresented: $showReopenSetupConfirm) {
                Button(LocalizationKey.commonCancel.localized, role: .cancel) { }
                Button(LocalizationKey.setupReopenConfirmAction.localized) {
                    hasCompletedOnboarding = false
                }
            } message: {
                Text(LocalizationKey.setupReopenConfirmMessage.localized)
            }
            .alert(LocalizationKey.resetConfirmTitle.localized,
                   isPresented: $showResetConfirm) {
                Button(LocalizationKey.commonCancel.localized, role: .cancel) { }
                Button(LocalizationKey.resetConfirmAction.localized, role: .destructive) {
                    performReset()
                }
            } message: {
                Text(LocalizationKey.resetConfirmMessage.localized)
            }
            .alert(LocalizationKey.errorResetFailed.localized,
                   isPresented: $showResetError) {
                Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
            }
        }
    }

    // MARK: - Appearance (task 5-8)

    private var appearanceSection: some View {
        Section(LocalizationKey.settingsAppearance.localized) {
            Picker(LocalizationKey.settingsAppearance.localized,
                   selection: $appearanceMode) {
                Text(LocalizationKey.appearanceSystem.localized)
                    .tag(AppearanceMode.system)
                Text(LocalizationKey.appearanceLight.localized)
                    .tag(AppearanceMode.light)
                Text(LocalizationKey.appearanceDark.localized)
                    .tag(AppearanceMode.dark)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Reopen setup (task 5-14)

    private var reopenSetupSection: some View {
        Section(LocalizationKey.settingsAppSetup.localized) {
            Button {
                showReopenSetupConfirm = true
            } label: {
                Label(LocalizationKey.settingsReopenSetup.localized,
                      systemImage: "arrow.counterclockwise")
            }
        }
    }

    // MARK: - Site management (task 3-2)

    private var managementSection: some View {
        Section {
            NavigationLink {
                SiteManagementView()
            } label: {
                Label(LocalizationKey.settingsSiteManagement.localized,
                      systemImage: "building.2")
            }
        }
    }

    // MARK: - Data management (task 5-11)

    private var dataManagementSection: some View {
        Section(LocalizationKey.settingsDataManagement.localized) {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label(LocalizationKey.settingsResetLocalData.localized,
                      systemImage: "trash")
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        Section {
            DisclaimerView()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    // MARK: - App version

    private var versionSection: some View {
        Section {
            LabeledContent(LocalizationKey.settingsAppVersion.localized,
                           value: viewModel.appVersion)
        }
    }

    // MARK: - Reset

    private func performReset() {
        do {
            // Delete all inspections (cascade: ChecklistItem + Inspection-owned Hazard)
            let inspections = try modelContext.fetch(FetchDescriptor<Inspection>())
            for inspection in inspections { modelContext.delete(inspection) }
            // Delete remaining hazards (standalone or any orphaned after cascade)
            let hazards = try modelContext.fetch(FetchDescriptor<Hazard>())
            for hazard in hazards { modelContext.delete(hazard) }
            // Delete all sites (cascade: Area)
            let sites = try modelContext.fetch(FetchDescriptor<Site>())
            for site in sites { modelContext.delete(site) }
            try modelContext.save()
            // Photo cleanup — failure does not roll back the SwiftData deletion
            try PhotoStorageService().deleteAllEvidencePhotos()
        } catch {
            showResetError = true
        }
    }
}

#Preview {
    SettingsView()
}
