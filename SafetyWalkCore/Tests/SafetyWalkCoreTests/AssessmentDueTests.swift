import Testing
import Foundation
@testable import SafetyWalkCore

// WO-7 → WO LEGAL-3A → WO LEGAL-3A R1: shared, jurisdiction- AND kind-aware re-assessment
// REVIEW reminder. Single source of truth for the review-reminder surfaces on iOS (home) and
// macOS (dashboard) — callers must not re-check kind/jurisdiction themselves. Only a
// KR-jurisdiction, `kind == .regular` assessment gets the annual (365-day) reminder, with a
// 30-day grace window before it. `initial`/`occasional` KR assessments never auto-flag — the
// annual cadence is a 정기(regular) concept only. Federal OSHA has no universal annual JHA
// deadline (LEGAL_READINESS_KR_US.md P0-4), so U.S. and unset-jurisdiction assessments must
// NEVER auto-flag, even long past the KR-style 365-day mark — the app does not invent a
// legal-sounding deadline it cannot verify. Boundaries are red-first (TDD).

@Suite("RiskAssessment.dueStatus — jurisdiction- and kind-aware annual review reminder (WO LEGAL-3A R1)")
struct AssessmentDueTests {

    private let cal = Calendar.current
    private var assessedAt: Date { cal.date(from: DateComponents(year: 2025, month: 1, day: 1))! }
    private func plus(_ days: Int) -> Date { cal.date(byAdding: .day, value: days, to: assessedAt)! }

    private func assessment(jurisdiction: JurisdictionCode?, assessedAt: Date?,
                            kind: RiskAssessmentKind = .regular) -> RiskAssessment {
        let ra = RiskAssessment(kind: kind, method: .frequencySeverity,
                                siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                                jurisdictionSnapshot: jurisdiction)
        ra.assessedAt = assessedAt
        return ra
    }

    private func kr(_ assessedAt: Date?) -> RiskAssessment { assessment(jurisdiction: .kr, assessedAt: assessedAt) }
    private func us(_ assessedAt: Date?) -> RiskAssessment { assessment(jurisdiction: .us, assessedAt: assessedAt) }
    private func unset(_ assessedAt: Date?) -> RiskAssessment { assessment(jurisdiction: nil, assessedAt: assessedAt) }

    // MARK: - KR: unchanged 365d + 30d grace math

    @Test func freshAssessmentIsNotDue() {
        #expect(kr(assessedAt).dueStatus(now: plus(0)) == .notDue)
    }

    @Test func wellWithinDeadlineIsNotDue() {
        #expect(kr(assessedAt).dueStatus(now: plus(300)) == .notDue)
    }

    @Test func dayBeforeGraceWindowIsNotDue() {
        // grace starts at deadline−30d = day 335; day 334 is still not due
        #expect(kr(assessedAt).dueStatus(now: plus(334)) == .notDue)
    }

    @Test func graceWindowStartIsDueSoon() {
        #expect(kr(assessedAt).dueStatus(now: plus(335)) == .dueSoon)
    }

    @Test func insideGraceWindowIsDueSoon() {
        #expect(kr(assessedAt).dueStatus(now: plus(350)) == .dueSoon)
    }

    @Test func dayBeforeDeadlineIsDueSoon() {
        #expect(kr(assessedAt).dueStatus(now: plus(364)) == .dueSoon)
    }

    @Test func atDeadlineIsOverdue() {
        #expect(kr(assessedAt).dueStatus(now: plus(365)) == .overdue)
    }

    @Test func pastDeadlineIsOverdue() {
        #expect(kr(assessedAt).dueStatus(now: plus(400)) == .overdue)
    }

    // MARK: - Kind gate (WO LEGAL-3A R1) — the annual cadence is a 정기(regular) concept only

    @Test func krInitialNeverAutoFlagsEvenPastTheDeadline() {
        let ra = assessment(jurisdiction: .kr, assessedAt: assessedAt, kind: .initial)
        #expect(ra.dueStatus(now: plus(365)) == .notDue)
        #expect(ra.dueStatus(now: plus(1000)) == .notDue)
    }

    @Test func krOccasionalNeverAutoFlagsEvenPastTheDeadline() {
        let ra = assessment(jurisdiction: .kr, assessedAt: assessedAt, kind: .occasional)
        #expect(ra.dueStatus(now: plus(365)) == .notDue)
        #expect(ra.dueStatus(now: plus(1000)) == .notDue)
    }

    // MARK: - Jurisdiction gate (WO LEGAL-3A P0-4)

    @Test func usNeverAutoFlagsEvenPastTheKRDeadline() {
        #expect(us(assessedAt).dueStatus(now: plus(365)) == .notDue)
        #expect(us(assessedAt).dueStatus(now: plus(1000)) == .notDue)
    }

    @Test func unsetJurisdictionNeverAutoFlagsEvenPastTheKRDeadline() {
        #expect(unset(assessedAt).dueStatus(now: plus(365)) == .notDue)
        #expect(unset(assessedAt).dueStatus(now: plus(1000)) == .notDue)
    }

    @Test func nilAssessedAtIsNeverDueRegardlessOfJurisdiction() {
        #expect(kr(nil).dueStatus(now: plus(1000)) == .notDue)
        #expect(us(nil).dueStatus(now: plus(1000)) == .notDue)
    }

    // Parity sweep — the KR annual rule across a wide offset range, alongside proof that US
    // never disagrees (stays notDue) at every one of the same offsets. Single Core source for
    // iOS + macOS (WO-7 / WO LEGAL-3A) — both screens call this same instance method.
    @Test func matchesAnnualRuleAcrossSweepForKROnlyAndUSNeverFlags() {
        for d in stride(from: 0, through: 420, by: 1) {
            let now = plus(d)
            let status = kr(assessedAt).dueStatus(now: now)
            let deadline = cal.date(byAdding: .day, value: 365, to: assessedAt)!
            let graceStart = cal.date(byAdding: .day, value: -30, to: deadline)!
            let isDue = now >= graceStart
            let overdue = now >= deadline
            #expect((status != .notDue) == isDue)
            #expect((status == .overdue) == overdue)
            #expect(us(assessedAt).dueStatus(now: now) == .notDue)
        }
    }
}
