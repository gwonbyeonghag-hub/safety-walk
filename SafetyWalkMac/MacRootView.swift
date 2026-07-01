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
            List(MacSection.allCases, selection: $section) { item in
                Label(item.titleKey.localized, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .safeAreaInset(edge: .bottom) { appearanceFooter }
        } detail: {
            detail(for: section ?? .dashboard)
                .frame(minWidth: 720)
        }
    }

    @ViewBuilder
    private func detail(for section: MacSection) -> some View {
        switch section {
        case .dashboard:       DashboardView()
        case .sites:           SitesBrowseView()
        case .inspections:     InspectionsBrowseView()
        case .hazards:         HazardsBrowseView()
        case .riskAssessments: RiskAssessmentsBrowseView()
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
