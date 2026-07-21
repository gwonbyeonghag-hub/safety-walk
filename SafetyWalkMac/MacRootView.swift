import SwiftUI
import SafetyWalkCore

/// The manager shell: a sidebar of sections + a detail pane (NavigationSplitView, macOS
/// HIG). Dashboard and Reports use a wide single pane; the browse sections show their own
/// list + read-only detail.
struct MacRootView: View {
    @State private var section: MacSection? = MacRootView.initialSection
    @AppStorage("com.safetywalk.appearanceMode") private var appearanceMode: AppearanceMode = .system

    /// DEBUG-only: lets a screenshot run open directly on a given section
    /// (`defaults write com.safetywalk.macos mac.debug.section reports`).
    private static var initialSection: MacSection? {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "mac.debug.section"),
           let s = MacSection(rawValue: raw) { return s }
        #endif
        return .dashboard
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                Section {
                    ForEach(MacSection.allCases) { item in
                        Label(item.titleKey.localized, systemImage: item.systemImage)
                            .tag(item)
                    }
                } header: {
                    Text(LocalizationKey.macSidebarOverview.localized)
                }
            }
            .tint(Color.macAccent)
            .navigationSplitViewColumnWidth(min: 208, ideal: 232, max: 300)
            .safeAreaInset(edge: .top, spacing: 0) { sidebarHeader }
            .safeAreaInset(edge: .bottom) { appearanceFooter }
        } detail: {
            detail(for: section ?? .dashboard)
                .frame(minWidth: 720)
        }
    }

    /// App-identity header (mockup `.acct`): brand mark + app name + manager role. Sits
    /// above the nav list; the native sidebar material shows through behind it.
    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: MacTheme.smallRadius)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.17, green: 0.42, blue: 0.84),
                                 Color(red: 0.09, green: 0.24, blue: 0.52)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizationKey.macAppName.localized)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.macInk)
                Text(LocalizationKey.macSidebarRole.localized)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.macMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, MacTheme.s2)
        .padding(.bottom, MacTheme.s3)
    }

    @ViewBuilder
    private func detail(for sec: MacSection) -> some View {
        switch sec {
        case .dashboard:       DashboardView(onSelectSection: { section = $0 })
        case .sites:           SitesBrowseView()
        case .inspections:     InspectionsBrowseView()
        case .hazards:         HazardsBrowseView()
        case .riskAssessments: RiskAssessmentsBrowseView()
        case .briefings:       SafetyBriefingsBrowseView()
        case .reports:         ReportHubView()
        }
    }

    private var appearanceFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(.secondary)
            Picker(LocalizationKey.settingsAppearance.localized, selection: $appearanceMode) {
                Text(LocalizationKey.appearanceSystem.localized).tag(AppearanceMode.system)
                Text(LocalizationKey.appearanceLight.localized).tag(AppearanceMode.light)
                Text(LocalizationKey.appearanceDark.localized).tag(AppearanceMode.dark)
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}
