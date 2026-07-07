import Testing
import Foundation
@testable import SafetyWalkCore

// WO-7: shared, pure re-assessment due status. Single source of truth for the "위험성평가
// 기한" surfaces on iOS (home) and (later) macOS. Must give the SAME verdict as the
// existing macOS DashboardView.DueBadge rule: an annual (365-day) deadline with a 30-day
// grace window before it — i.e. `dueStatus != .notDue` ⟺ macOS `isDue` (now ≥ deadline−30d),
// and `.overdue` ⟺ macOS `overdue` (now ≥ deadline). Boundaries are red-first (TDD).

@Suite("RiskAssessment.dueStatus — annual deadline + 30d grace (WO-7)")
struct AssessmentDueTests {

    private let cal = Calendar.current
    private var assessedAt: Date { cal.date(from: DateComponents(year: 2025, month: 1, day: 1))! }
    private func plus(_ days: Int) -> Date { cal.date(byAdding: .day, value: days, to: assessedAt)! }

    @Test func freshAssessmentIsNotDue() {
        #expect(RiskAssessment.dueStatus(assessedAt: assessedAt, now: plus(0)) == .notDue)
    }

    @Test func wellWithinDeadlineIsNotDue() {
        #expect(RiskAssessment.dueStatus(assessedAt: assessedAt, now: plus(300)) == .notDue)
    }

    @Test func dayBeforeGraceWindowIsNotDue() {
        // grace starts at deadline−30d = day 335; day 334 is still not due
        #expect(RiskAssessment.dueStatus(assessedAt: assessedAt, now: plus(334)) == .notDue)
    }

    @Test func graceWindowStartIsDueSoon() {
        #expect(RiskAssessment.dueStatus(assessedAt: assessedAt, now: plus(335)) == .dueSoon)
    }

    @Test func insideGraceWindowIsDueSoon() {
        #expect(RiskAssessment.dueStatus(assessedAt: assessedAt, now: plus(350)) == .dueSoon)
    }

    @Test func dayBeforeDeadlineIsDueSoon() {
        #expect(RiskAssessment.dueStatus(assessedAt: assessedAt, now: plus(364)) == .dueSoon)
    }

    @Test func atDeadlineIsOverdue() {
        #expect(RiskAssessment.dueStatus(assessedAt: assessedAt, now: plus(365)) == .overdue)
    }

    @Test func pastDeadlineIsOverdue() {
        #expect(RiskAssessment.dueStatus(assessedAt: assessedAt, now: plus(400)) == .overdue)
    }

    // Parity with the macOS DueBadge rule across a sweep of offsets.
    @Test func matchesMacDueBadgeRule() {
        for d in stride(from: 0, through: 420, by: 1) {
            let now = plus(d)
            let status = RiskAssessment.dueStatus(assessedAt: assessedAt, now: now)
            let deadline = cal.date(byAdding: .day, value: 365, to: assessedAt)!
            let graceStart = cal.date(byAdding: .day, value: -30, to: deadline)!
            let macIsDue = now >= graceStart          // macOS DueBadge.isDue
            let macOverdue = now >= deadline          // macOS DueBadge.overdue
            #expect((status != .notDue) == macIsDue)
            #expect((status == .overdue) == macOverdue)
        }
    }
}
