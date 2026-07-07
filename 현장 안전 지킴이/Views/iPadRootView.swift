import SwiftUI
import SafetyWalkCore

// WO-7: iPad (regular width) native shell. A NavigationSplitView with a section sidebar +
// the EXISTING iOS content views reused as the detail — no content view is rewritten.
// iPhone / compact width keeps the existing tab bar (see ContentView.mainShell), so the
// iPhone layout is unchanged. Uses only iOS/shared design assets (RiskChip, AccentColor,
// LocalizationKey) — the macOS-only MacDesign tokens are intentionally NOT imported.

/// Sidebar sections for the iPad shell. Mirrors the iPhone tabs plus 위험성평가, which on
/// iPhone lives under Home; on iPad it is promoted to a first-class sidebar section
/// (reusing `RiskAssessmentListView`).
enum IPadSection: String, CaseIterable, Identifiable, Hashable {
    case home, inspection, hazards, history, riskAssessments, settings

    var id: String { rawValue }

    var titleKey: LocalizationKey {
        switch self {
        case .home:            return .tabHome
        case .inspection:      return .tabInspection
        case .hazards:         return .tabHazards
        case .history:         return .tabHistory
        case .riskAssessments: return .raTitle
        case .settings:        return .tabSettings
        }
    }

    var systemImage: String {
        switch self {
        case .home:            return "house"
        case .inspection:      return "checklist"
        case .hazards:         return "exclamationmark.triangle"
        case .history:         return "clock"
        case .riskAssessments: return "list.clipboard"
        case .settings:        return "gear"
        }
    }
}

struct IPadRootView: View {
    @State private var section: IPadSection? = .home
    @AppStorage("com.safetywalk.inspectorName") private var inspectorName = ""

    var body: some View {
        NavigationSplitView {
            List(IPadSection.allCases, selection: $section) { item in
                Label(item.titleKey.localized, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 264, max: 320)
            .safeAreaInset(edge: .top, spacing: 0) { sidebarHeader }
        } detail: {
            detail(for: section ?? .home)
        }
    }

    // MARK: - Detail (existing views reused)

    @ViewBuilder
    private func detail(for section: IPadSection) -> some View {
        switch section {
        case .home:            HomeView()
        case .inspection:      InspectionView()
        case .hazards:         HazardsTabView()
        case .history:         HistoryTabView()
        // RiskAssessmentListView is designed to be pushed (owns no NavigationStack), so it
        // gets one here to render its title/toolbar as a top-level section.
        case .riskAssessments: NavigationStack { RiskAssessmentListView() }
        case .settings:        SettingsView()
        }
    }

    // MARK: - Sidebar identity header (mockup .acct)

    private var sidebarHeader: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.17, green: 0.42, blue: 0.84),
                                 Color(red: 0.09, green: 0.24, blue: 0.52)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizationKey.macAppName.localized)   // shared app-name string
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(inspectorName.isEmpty
                     ? LocalizationKey.ipadSidebarRole.localized
                     : inspectorName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
