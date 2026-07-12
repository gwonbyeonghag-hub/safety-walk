#if DEBUG
import Foundation
import SwiftData
import SafetyWalkCore

/// DEBUG- and UI-test-only History seeding for verification / App Store screenshots (WO-13).
///
/// Activated **only** by the launch argument `-com.safetywalk.uitestSeedHistory 1` — it never
/// runs in a normal launch, and the entire file compiles out of Release (`#if DEBUG`), so no
/// seed code or seed strings ship. It builds a throwaway **in-memory** `ModelContainer`
/// (`isStoredInMemoryOnly`) — the real on-disk / CloudKit store is never opened or written —
/// populated with backdated inspections across three sites so that:
///   • every date bucket renders with real content — 오늘 / 어제 / 이번 주 / 이번 달 / 그이전, and
///   • site-grouped mode shows several named sections.
///
/// It also pins `HistoryClock` to a fixed Wednesday (2026-07-08) via `com.safetywalk.uitestNow`
/// so the buckets are deterministic no matter which weekday the capture runs on (a Sunday, for
/// instance, has no "earlier this week" slot).
enum HistorySeed {

    static var isRequested: Bool {
        UserDefaults.standard.bool(forKey: "com.safetywalk.uitestSeedHistory")
    }

    /// Fixed reference "now" shared by the seed data and `HistoryClock`: Wed 2026-07-08 12:00
    /// in the device calendar (noon avoids midnight day-boundary flips).
    private static func referenceNow(_ calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 8; comps.hour = 12
        return calendar.date(from: comps) ?? Date()
    }

    static func makeSeededInMemoryContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)

        let calendar = Calendar.current
        let now = referenceNow(calendar)
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "com.safetywalk.uitestNow")

        seed(into: ModelContext(container), now: now, calendar: calendar)
        return container
    }

    // MARK: - Seed content

    private static func seed(into context: ModelContext, now: Date, calendar: Calendar) {
        let siteA = Site(name: "가나물류센터 A동")
        let siteB = Site(name: "나래건설 2공구")
        let siteC = Site(name: "다산타워 리모델링")
        [siteA, siteB, siteC].forEach { context.insert($0) }

        func day(_ year: Int, _ month: Int, _ dayOfMonth: Int, _ hour: Int = 10) -> Date {
            var c = DateComponents()
            c.year = year; c.month = month; c.day = dayOfMonth; c.hour = hour
            return calendar.date(from: c) ?? now
        }

        // (site, area, startedAt, completed, total, pass, fail) — one per date bucket.
        let plan: [(Site, String?, Date, Bool, Int, Int, Int)] = [
            (siteA, "지하주차장", calendar.date(byAdding: .hour, value: -3, to: now) ?? now, true, 8, 6, 2), // 오늘
            (siteB, "3층 골조",   calendar.date(byAdding: .day,  value: -1, to: now) ?? now, false, 5, 3, 0), // 어제 (진행 중)
            (siteC, "옥상 방수",  day(2026, 7, 6),  true, 10, 9, 1), // 이번 주 (월)
            (siteA, "하역장",     day(2026, 7, 1),  true, 6, 6, 0),  // 이번 달 (지난 주)
            (siteB, "가설 전기",  day(2026, 6, 10), true, 7, 5, 2),  // 그이전: 2026년 6월
            (siteC, "외벽 마감",  day(2026, 5, 12), true, 4, 4, 0)   // 그이전: 2026년 5월
        ]

        for (site, area, startedAt, completed, total, pass, fail) in plan {
            addInspection(into: context, site: site, area: area, startedAt: startedAt,
                          completed: completed, total: total, pass: pass, fail: fail)
        }

        try? context.save()
    }

    private static func addInspection(into context: ModelContext,
                                      site: Site, area: String?, startedAt: Date,
                                      completed: Bool, total: Int, pass: Int, fail: Int) {
        let inspection = Inspection(siteId: site.id, siteName: site.name, areaName: area,
                                    inspectorName: "김안전", templateId: "korea-basic")
        inspection.startedAt = startedAt
        if completed {
            inspection.status = .completed
            inspection.completedAt = startedAt.addingTimeInterval(3600)
        } else {
            inspection.status = .inProgress
        }

        var items: [ChecklistItem] = []
        for index in 0..<total {
            let item = ChecklistItem(inspectionId: inspection.id, templateItemId: "seed-\(index)",
                                     title: "점검 항목 \(index + 1)", category: "일반 안전", sortOrder: index)
            if index < fail { item.result = .fail }
            else if index < fail + pass { item.result = .pass }
            else { item.result = .unchecked }
            item.inspection = inspection
            items.append(item)
        }
        inspection.items = items

        context.insert(inspection)
        items.forEach { context.insert($0) }
    }
}
#endif
