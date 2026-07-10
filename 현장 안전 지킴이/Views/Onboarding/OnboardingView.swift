import SwiftUI

/// First-launch initial setup screen.
///
/// This is **not** a login or account flow — SafetyWalk is a local-first,
/// offline-only app with no server, no accounts, no roles, and no cloud sync.
/// All this screen does is collect two values needed by the rest of the app:
/// the inspector's display name (stored in `UserDefaults`) and the UI language
/// (stored via `LocalizationManager`, which also selects the matching region
/// profile). Both are editable later from the Settings tab. Setting
/// `hasCompletedOnboarding = true` makes `ContentView` swap this screen out for
/// the main TabView.
struct OnboardingView: View {

    @AppStorage("com.safetywalk.hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    // Read the previously saved name so the field is prefilled when reopened.
    @AppStorage("com.safetywalk.inspectorName")
    private var savedInspectorName = ""

    @State private var inspectorName: String = ""

    private var trimmedName: String {
        inspectorName.trimmingCharacters(in: .whitespaces)
    }

    private var canStart: Bool { !trimmedName.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                nameSection
                languageSection
                DisclaimerView()
                startSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Prefill existing name so reopening setup doesn't lose it.
            if inspectorName.isEmpty { inspectorName = savedInspectorName }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .padding(.bottom, 4)
            Text(LocalizationKey.onboardingTitle.localized)
                .font(.largeTitle.weight(.bold))
            Text(LocalizationKey.onboardingSubtitle.localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizationKey.onboardingInspectorName.localized)
                .font(.subheadline.weight(.semibold))
            TextField(LocalizationKey.onboardingInspectorName.localized,
                      text: $inspectorName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .submitLabel(.done)
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizationKey.settingsLanguage.localized)
                .font(.subheadline.weight(.semibold))
            Picker(LocalizationKey.settingsLanguage.localized,
                   selection: Binding(
                        get: { LocalizationManager.shared.language },
                        set: { selectLanguage($0) })) {
                Text(LocalizationKey.languageKorean.localized)
                    .tag(AppLanguage.korean)
                Text(LocalizationKey.languageEnglish.localized)
                    .tag(AppLanguage.english)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !canStart {
                Text(LocalizationKey.onboardingNameRequired.localized)
                    .font(.caption)
                    .foregroundStyle(Color.warning)
            }
            Button {
                completeOnboarding()
            } label: {
                Text(LocalizationKey.onboardingStart.localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStart)
        }
    }

    // MARK: - Action

    /// Switches language live. Toggling rebuilds the whole tree (via `.id` in
    /// `SafetyWalkApp`), which re-creates this view, so persist any in-progress name
    /// first and let `onAppear` restore it from `savedInspectorName`.
    private func selectLanguage(_ lang: AppLanguage) {
        if !trimmedName.isEmpty {
            UserDefaults.standard.set(trimmedName,
                                      forKey: "com.safetywalk.inspectorName")
        }
        LocalizationManager.shared.set(lang)
    }

    private func completeOnboarding() {
        guard canStart else { return }
        // Persist to the same UserDefaults keys SettingsViewModel reads from,
        // so the saved name appears in Settings on next render.
        UserDefaults.standard.set(trimmedName,
                                  forKey: "com.safetywalk.inspectorName")
        // Ensure the region profile matches the selected (or system-default) language,
        // even if the user never touched the toggle.
        LocalizationManager.shared.set(LocalizationManager.shared.language)
        hasCompletedOnboarding = true
    }
}
