import Foundation
import SafetyWalkCore

// WO-13 PART A: History-tab grouping. Pure, display-layer-only logic that turns the
// already-filtered inspection list into ordered sections. Deliberately free of SwiftUI
// and locale formatting so it is deterministic and unit-testable (see
// HistoryGroupingTests) — the View maps `HistorySection` to a localized header string
// via `displayTitle`. No data / model / query changes: it only reads `startedAt` and
// `siteName` off the inspections it is handed.

/// How the History tab groups its rows. Coexists with the existing status filter.
enum HistoryGroupMode: Hashable {
    case date
    case site
}

/// A semantic section header. Kept locale-free (an enum, not a formatted string) so the
/// grouping/bucketing is deterministic under test; `displayTitle` does the localization.
enum HistorySection: Hashable {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    /// Anything older than this month, one section per calendar month ("2026년 3월").
    case earlier(year: Int, month: Int)
    /// Site-grouped mode: one section per `siteName`.
    case site(name: String)
}

/// One rendered section: a header plus the rows under it (already newest-first).
struct HistoryGroup: Identifiable {
    let section: HistorySection
    let inspections: [Inspection]
    var id: HistorySection { section }
}

enum HistoryGrouping {

    /// Groups `inspections` (assumed already status-filtered) into ordered sections.
    /// Sections and the rows within them are ordered newest-first, except site mode whose
    /// sections are ordered by site name. Empty sections are never produced.
    static func groups(for inspections: [Inspection],
                       mode: HistoryGroupMode,
                       now: Date,
                       calendar: Calendar = .current) -> [HistoryGroup] {
        switch mode {
        case .date: return byDate(inspections, now: now, calendar: calendar)
        case .site: return bySite(inspections)
        }
    }

    // MARK: - Date grouping

    private static func byDate(_ inspections: [Inspection],
                              now: Date,
                              calendar: Calendar) -> [HistoryGroup] {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)
        var buckets: [HistorySection: [Inspection]] = [:]
        for inspection in inspections {
            let section = dateSection(for: inspection.startedAt,
                                      now: now, yesterday: yesterday, calendar: calendar)
            buckets[section, default: []].append(inspection)
        }
        return buckets
            .map { HistoryGroup(section: $0.key,
                                inspections: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { dateOrder($0.section) < dateOrder($1.section) }
    }

    private static func dateSection(for date: Date,
                                    now: Date,
                                    yesterday: Date?,
                                    calendar: Calendar) -> HistorySection {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        if let yesterday, calendar.isDate(date, inSameDayAs: yesterday) { return .yesterday }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return .thisWeek }
        if calendar.isDate(date, equalTo: now, toGranularity: .month) { return .thisMonth }
        let comps = calendar.dateComponents([.year, .month], from: date)
        return .earlier(year: comps.year ?? 0, month: comps.month ?? 0)
    }

    /// Fixed buckets first, then older months newest-first (negated so larger year/month sorts earlier).
    private static func dateOrder(_ section: HistorySection) -> (Int, Int, Int) {
        switch section {
        case .today:                       return (0, 0, 0)
        case .yesterday:                   return (1, 0, 0)
        case .thisWeek:                    return (2, 0, 0)
        case .thisMonth:                   return (3, 0, 0)
        case .earlier(let year, let month): return (4, -year, -month)
        case .site:                        return (5, 0, 0)
        }
    }

    // MARK: - Site grouping

    private static func bySite(_ inspections: [Inspection]) -> [HistoryGroup] {
        Dictionary(grouping: inspections, by: { $0.siteName })
            .map { name, items in
                HistoryGroup(section: .site(name: name),
                             inspections: items.sorted { $0.startedAt > $1.startedAt })
            }
            .sorted { lhs, rhs in
                guard case let .site(l) = lhs.section, case let .site(r) = rhs.section else { return false }
                return l.localizedStandardCompare(r) == .orderedAscending
            }
    }
}

// MARK: - Localized display (View-facing; not part of the tested pure logic)

extension HistorySection {
    /// The header string shown in the List. Fixed date buckets come from
    /// `LocalizationKey` (ko/en); older buckets are formatted "YYYY년 M월" in the active
    /// language; site sections show the site name verbatim.
    var displayTitle: String {
        switch self {
        case .today:     return LocalizationKey.historyGroupToday.localized
        case .yesterday: return LocalizationKey.historyGroupYesterday.localized
        case .thisWeek:  return LocalizationKey.historyGroupThisWeek.localized
        case .thisMonth: return LocalizationKey.historyGroupThisMonth.localized
        case .earlier(let year, let month):
            return Self.monthYearTitle(year: year, month: month)
        case .site(let name):
            return name
        }
    }

    private static func monthYearTitle(year: Int, month: Int) -> String {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let calendar = Calendar.current
        guard let date = calendar.date(from: comps) else { return "\(year)" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationManager.shared.language.rawValue)
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }
}
