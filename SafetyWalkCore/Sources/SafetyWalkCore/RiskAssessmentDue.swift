import Foundation

/// Where a regular (정기) risk assessment sits against its annual re-assessment deadline.
public enum AssessmentDueStatus: Sendable, Hashable {
    case notDue      // comfortably before the deadline
    case dueSoon     // within the 30-day grace window before the deadline
    case overdue     // on or past the deadline
}

public extension RiskAssessment {
    /// Pure re-assessment due status — the single source of truth for every "위험성평가
    /// 기한" surface (WO-7). A 정기 assessment should be re-run at least annually; this
    /// flags the 30 days before the 1-year mark as `.dueSoon` and the deadline onward as
    /// `.overdue`. Date-only and side-effect-free (inject `now`/`calendar` in tests); the
    /// caller decides which assessments qualify (typically `kind == .regular`), exactly as
    /// the macOS dashboard already filters before badging.
    ///
    /// Verdict is identical to macOS `DashboardView.DueBadge` (isDue = now ≥ deadline−30d,
    /// overdue = now ≥ deadline), so macOS can converge onto this function without any
    /// behavior change.
    static func dueStatus(assessedAt: Date,
                          now: Date = Date(),
                          calendar: Calendar = .current) -> AssessmentDueStatus {
        guard let deadline = calendar.date(byAdding: .day, value: 365, to: assessedAt) else {
            return .notDue
        }
        if now >= deadline { return .overdue }
        guard let graceStart = calendar.date(byAdding: .day, value: -30, to: deadline) else {
            return .notDue
        }
        return now >= graceStart ? .dueSoon : .notDue
    }
}
