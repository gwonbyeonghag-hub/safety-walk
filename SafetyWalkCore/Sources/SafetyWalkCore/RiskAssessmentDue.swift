import Foundation

/// Where a regular (정기) risk assessment sits against its jurisdiction's product review
/// reminder. This is a review reminder, never a legal deadline verdict (CLAUDE.md No legal
/// judgment / LEGAL_READINESS_KR_US.md P0-4).
public enum AssessmentDueStatus: Sendable, Hashable {
    case notDue      // comfortably before the deadline, or no jurisdiction rule applies here
    case dueSoon     // within the 30-day grace window before the deadline
    case overdue     // on or past the deadline
}

public extension RiskAssessment {
    /// Pure, jurisdiction-aware re-assessment REVIEW reminder — the single source of truth for
    /// every review-reminder surface on iOS (home) and macOS (dashboard) (WO-7, WO LEGAL-3A,
    /// WO LEGAL-3A R1). Callers must NOT re-check `kind`/jurisdiction themselves — every
    /// qualifying condition lives here so there is exactly one policy point.
    ///
    /// Only a **KR-jurisdiction, `kind == .regular`** assessment gets the automatic annual
    /// (365-day) reminder, with the 30 days before the deadline flagged `.dueSoon` and the
    /// deadline onward `.overdue`. `initial`/`occasional` KR assessments never auto-flag — the
    /// annual cadence only applies to 정기(regular) assessments (WO LEGAL-3A R1). Federal OSHA
    /// has no universal annual JHA/risk-assessment deadline (LEGAL_READINESS_KR_US.md P0-4), so
    /// **U.S. and unset-jurisdiction** assessments always resolve `.notDue` — the app never shows
    /// a legal-sounding deadline it cannot verify for that jurisdiction. An assessment that has
    /// not been assessed yet (`assessedAt == nil`) is also always `.notDue` — there is nothing to
    /// measure a deadline from.
    ///
    /// Date-only and side-effect-free (inject `now`/`calendar` in tests).
    func dueStatus(now: Date = Date(), calendar: Calendar = .current) -> AssessmentDueStatus {
        guard kind == .regular, jurisdictionSnapshot == .kr, let assessedAt else { return .notDue }
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
