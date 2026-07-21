import SwiftUI
import SafetyWalkCore

// Small macOS-only helpers for the manager shell (WO-4). Kept separate from the shared
// iOS files so nothing here leaks back into the iOS target.

extension AppearanceMode {
    /// nil → follow system. Mirrors the iOS app's mapping (SafetyWalkApp.swift) so the
    /// same `com.safetywalk.appearanceMode` preference drives both platforms.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

extension Color {
    /// Cool interactive accent (DESIGN_DIRECTION §1: navy = app chrome / interactive,
    /// warm ramp reserved for risk). WO-8: now the adaptive mockup accent
    /// (`#2360C9` light / `#5C9BF5` dark) so every control tint tracks light/dark.
    static var brandNavy: Color { .macAccent }
}

/// Manager dashboard section identity (sidebar).
enum MacSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case sites
    case inspections
    case hazards
    case riskAssessments
    case briefings
    case reports

    var id: String { rawValue }

    var titleKey: LocalizationKey {
        switch self {
        case .dashboard:       return .macSectionDashboard
        case .sites:           return .macSectionSites
        case .inspections:     return .macSectionInspections
        case .hazards:         return .macSectionHazards
        case .riskAssessments: return .macSectionRiskAssessments
        case .briefings:       return .macSectionBriefings
        case .reports:         return .macSectionReports
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:       return "square.grid.2x2"
        case .sites:           return "building.2"
        case .inspections:     return "checklist"
        case .hazards:         return "exclamationmark.triangle"
        case .riskAssessments: return "tablecells"
        case .briefings:       return "person.3"
        case .reports:         return "doc.text"
        }
    }
}

/// A wrapping horizontal stack (flow layout) for small pills like area names/tags.
struct WrappingHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    var spacing: CGFloat = 6
    @ViewBuilder let content: (Data.Element) -> Content

    init(_ data: Data, spacing: CGFloat = 6, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        FlowLayout(spacing: spacing) {
            ForEach(Array(data), id: \.self) { content($0) }
        }
    }
}

/// Minimal flow layout (left-to-right, wrapping) using the macOS 14 `Layout` protocol.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// A calm card container used across the dashboard and browse detail panes.
/// WO-8: mockup card — token surface + hairline border + soft shadow, with the small
/// uppercase `MacCardLabel` header (DESIGN_DIRECTION: calm-dense, HIG).
struct MacCard<Content: View>: View {
    var title: String? = nil
    var systemImage: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: MacTheme.s3) {
            if let title {
                MacCardLabel(text: title, systemImage: systemImage)
            }
            content
        }
        .padding(MacTheme.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macCardSurface()
    }
}
