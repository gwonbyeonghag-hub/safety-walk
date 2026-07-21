import SwiftUI
import SafetyWalkCore

// WO-7: iPad (regular width) native shell. A NavigationSplitView with a section sidebar +
// the EXISTING iOS content views reused as the detail — no content view is rewritten.
// iPhone / compact width keeps the existing tab bar (see ContentView.mainShell), so the
// iPhone layout is unchanged. Uses only iOS/shared design assets (RiskChip, AccentColor,
// LocalizationKey) — the macOS-only MacDesign tokens are intentionally NOT imported.

/// Sidebar sections for the iPad shell. Mirrors the iPhone tabs plus 위험성평가·TBM 안전
/// 브리핑, which on iPhone live under Home; on iPad both are promoted to first-class sidebar
/// sections (reusing `RiskAssessmentListView`/`SafetyBriefingListView` — WO LEGAL-TBM-2).
enum IPadSection: String, CaseIterable, Identifiable, Hashable {
    case home, inspection, hazards, history, riskAssessments, briefings, settings

    var id: String { rawValue }

    var titleKey: LocalizationKey {
        switch self {
        case .home:            return .tabHome
        case .inspection:      return .tabInspection
        case .hazards:         return .tabHazards
        case .history:         return .tabHistory
        case .riskAssessments: return .raTitle
        case .briefings:       return .tbmTitle
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
        case .briefings:       return "person.3.fill"
        case .settings:        return "gear"
        }
    }
}

struct IPadRootView: View {
    @State private var section: IPadSection? = .home
    // WO-12: default to `.all` (sidebar always visible) rather than letting
    // NavigationSplitView decide — starting collapsed required a reveal tap before the
    // detail column's own controls were reliably hittable (see WO-12 fix note below).
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("com.safetywalk.inspectorName") private var inspectorName = ""

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(IPadSection.allCases, selection: $section) { item in
                Label(item.titleKey.localized, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 264, max: 320)
            .safeAreaInset(edge: .top, spacing: 0) { sidebarHeader }
        } detail: {
            detail(for: section ?? .home)
        }
        // WO-12 fix: `.automatic` was resolving to an overlay/compact-style presentation
        // for the detail column despite ample width, which silently swallowed the first
        // tap on any control right after switching sidebar sections (no crash, no sheet,
        // no paywall — just nothing; a second tap always worked). `.balanced` forces a
        // true persistent 2-column layout.
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Detail (existing views reused)

    @ViewBuilder
    private func detail(for section: IPadSection) -> some View {
        switch section {
        case .home:            HomeView()
        case .inspection:      InspectionView()
        case .hazards:         HazardsTabView()
        case .history:         HistoryTabView()
        // RiskAssessmentListView/SafetyBriefingListView are designed to be pushed (own no
        // NavigationStack), so they get one here to render their title/toolbar as a
        // top-level section.
        case .riskAssessments: NavigationStack { RiskAssessmentListView() }
        case .briefings:       NavigationStack { SafetyBriefingListView() }
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
