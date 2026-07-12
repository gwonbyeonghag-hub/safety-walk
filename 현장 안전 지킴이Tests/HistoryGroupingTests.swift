import Testing
import Foundation
import SafetyWalkCore
@testable import 현장_안전_지킴이

// WO-13 PART A: boundary coverage for the pure History grouping logic.
// A fixed Gregorian/Asia-Seoul calendar with a Monday first-weekday and a fixed `now`
// (Wed 2026-06-17) make the date buckets deterministic and independent of when the
// suite runs.
struct HistoryGroupingTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        c.firstWeekday = 2 // Monday → Mon..Sun weeks
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return calendar.date(from: comps)!
    }

    private func inspection(site: String, at startedAt: Date) -> Inspection {
        let i = Inspection(siteId: UUID(), siteName: site,
                           inspectorName: "T", templateId: "korea-basic")
        i.startedAt = startedAt
        return i
    }

    private var now: Date { date(2026, 6, 17, 12) } // Wednesday

    // MARK: - data 0

    @Test func emptyInputProducesNoGroups() {
        #expect(HistoryGrouping.groups(for: [], mode: .date, now: now, calendar: calendar).isEmpty)
        #expect(HistoryGrouping.groups(for: [], mode: .site, now: now, calendar: calendar).isEmpty)
    }

    // MARK: - date boundaries (오늘/어제/이번 주/이번 달/그이전)

    @Test func dateBucketsMapToCorrectSectionsInOrder() {
        let items = [
            inspection(site: "A", at: date(2026, 6, 17, 9)),  // today
            inspection(site: "B", at: date(2026, 6, 16, 10)), // yesterday
            inspection(site: "C", at: date(2026, 6, 15, 10)), // this week (Mon, same week)
            inspection(site: "D", at: date(2026, 6, 8, 10)),  // this month, earlier week
            inspection(site: "E", at: date(2026, 5, 8, 10)),  // earlier: 2026-05
            inspection(site: "F", at: date(2025, 12, 20, 10)) // earlier: 2025-12
        ]
        let groups = HistoryGrouping.groups(for: items, mode: .date, now: now, calendar: calendar)

        #expect(groups.map(\.section) == [
            .today, .yesterday, .thisWeek, .thisMonth,
            .earlier(year: 2026, month: 5), .earlier(year: 2025, month: 12)
        ])
        #expect(groups.allSatisfy { $0.inspections.count == 1 })
    }

    @Test func noEmptyGroupsForMissingBuckets() {
        let items = [
            inspection(site: "A", at: date(2026, 6, 17, 9)),   // today
            inspection(site: "F", at: date(2025, 12, 20, 10))  // earlier only
        ]
        let groups = HistoryGrouping.groups(for: items, mode: .date, now: now, calendar: calendar)
        // No yesterday / this-week / this-month sections should be emitted.
        #expect(groups.map(\.section) == [.today, .earlier(year: 2025, month: 12)])
    }

    @Test func rowsWithinDateGroupAreNewestFirst() {
        let early = inspection(site: "A", at: date(2026, 6, 17, 8))
        let late  = inspection(site: "B", at: date(2026, 6, 17, 20))
        let groups = HistoryGrouping.groups(for: [early, late], mode: .date, now: now, calendar: calendar)

        #expect(groups.count == 1)
        #expect(groups[0].section == .today)
        #expect(groups[0].inspections.map(\.siteName) == ["B", "A"]) // newest first
    }

    @Test func earlierMonthsSortedNewestFirst() {
        let items = [
            inspection(site: "old", at: date(2025, 12, 20, 10)), // 2025-12
            inspection(site: "mid", at: date(2026, 1, 5, 10)),   // 2026-01
            inspection(site: "new", at: date(2026, 5, 8, 10))    // 2026-05
        ]
        let groups = HistoryGrouping.groups(for: items, mode: .date, now: now, calendar: calendar)
        #expect(groups.map(\.section) == [
            .earlier(year: 2026, month: 5),
            .earlier(year: 2026, month: 1),
            .earlier(year: 2025, month: 12)
        ])
    }

    // MARK: - site boundaries (현장명 순 / 동률)

    @Test func siteModeGroupsSortedByNameAscending() {
        let items = [
            inspection(site: "다현장", at: date(2026, 6, 17, 9)),
            inspection(site: "가현장", at: date(2026, 6, 16, 9)),
            inspection(site: "나현장", at: date(2026, 6, 15, 9))
        ]
        let groups = HistoryGrouping.groups(for: items, mode: .site, now: now, calendar: calendar)
        #expect(groups.map(\.section) == [
            .site(name: "가현장"), .site(name: "나현장"), .site(name: "다현장")
        ])
    }

    @Test func siteModeMergesSameNameNewestFirst() {
        let items = [
            inspection(site: "가현장", at: date(2026, 6, 10, 9)),
            inspection(site: "가현장", at: date(2026, 6, 17, 9)),
            inspection(site: "나현장", at: date(2026, 6, 12, 9))
        ]
        let groups = HistoryGrouping.groups(for: items, mode: .site, now: now, calendar: calendar)

        #expect(groups.map(\.section) == [.site(name: "가현장"), .site(name: "나현장")])
        // Same site name collapses into one section, newest-first within it.
        #expect(groups[0].inspections.count == 2)
        #expect(groups[0].inspections.map(\.startedAt) == [date(2026, 6, 17, 9), date(2026, 6, 10, 9)])
    }
}
