#if DEBUG
import Foundation
import SwiftData
import SafetyWalkCore

/// Sample data for the macOS manager shell (WO-4, DEBUG only — never in a release build).
/// Represents what a manager would see synced from the field iPhones once WO-3 wires
/// CloudKit: several sites, completed inspections with findings, open hazards, and one
/// risk assessment per method (3-level / freq×severity / checklist / JSA).
///
/// User-entered fields (site names, hazard text, task steps) are literal strings — real
/// user input is never localized. Only app chrome routes through LocalizationKey.
enum SeedData {

    /// Marks a seeded item/hazard as "has a photo" without a real JPEG — MacReportPhotos
    /// only checks for non-nil `photoData` and draws its own placeholder image.
    static let seedPhotoMarker = Data("seed".utf8)

    @MainActor
    static func populate(_ context: ModelContext) {
        // Idempotent: don't double-seed if a store already has content.
        if (try? context.fetch(FetchDescriptor<Site>()))?.isEmpty == false { return }

        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now) ?? now }

        // Real checklist template (data-driven, per CLAUDE.md) for inspection items.
        let template = (try? ChecklistTemplateLoader().load(for: .korea))?.first

        // MARK: Sites + areas
        let siteA = Site(name: "○○건설 현장", address: "서울특별시 강남구 테헤란로 000")
        let siteB = Site(name: "△△물류센터", address: "경기도 이천시 물류로 12")
        let siteC = Site(name: "□□플랜트", address: "울산광역시 남구 산업로 340")
        for (site, areas) in [(siteA, ["1층 전기실", "2층 작업장", "옥상"]),
                              (siteB, ["하역장", "보관창고"]),
                              (siteC, ["생산라인 1", "생산라인 2"])] {
            context.insert(site)
            site.areas = areas.map { Area(name: $0, siteId: site.id) }
        }

        // MARK: Inspections (completed) with checklist items + hazards
        let inspA = makeInspection(site: siteA, area: "1층 전기실", inspector: "김현장",
                                   template: template, startedAt: daysAgo(3),
                                   context: context, itemCount: 15, failEvery: 4, photoEvery: 5)
        let inspB = makeInspection(site: siteB, area: "하역장", inspector: "이관리",
                                   template: template, startedAt: daysAgo(9),
                                   context: context, itemCount: 9, failEvery: 3, photoEvery: 4)
        let inspC = makeInspection(site: siteC, area: "생산라인 2", inspector: "박점검",
                                   template: template, startedAt: daysAgo(1),
                                   context: context, itemCount: 12, failEvery: 5, photoEvery: 6)

        // MARK: Hazards (mix of level + corrective status; some open)
        seedHazard(siteId: siteA.id, inspection: inspA, location: "1층 배전반",
                   type: .electrical, level: .high, desc: "배전반 커버 파손 — 충전부 노출",
                   status: .notStarted, at: daysAgo(3), context: context, photo: true)
        seedHazard(siteId: siteA.id, inspection: inspA, location: "2층 개구부",
                   type: .fallRisk, level: .high, desc: "안전난간 미설치 개구부",
                   status: .inProgress, at: daysAgo(3), context: context, photo: true)
        seedHazard(siteId: siteA.id, inspection: inspA, location: "옥상 통로",
                   type: .general, level: .low, desc: "자재 적치로 통로 일부 협소",
                   status: .completed, at: daysAgo(12), context: context, photo: false)
        seedHazard(siteId: siteB.id, inspection: inspB, location: "하역장 램프",
                   type: .fallRisk, level: .medium, desc: "미끄럼 방지 표면 마모",
                   status: .notStarted, at: daysAgo(9), context: context, photo: true)
        seedHazard(siteId: siteB.id, inspection: inspB, location: "보관창고",
                   type: .chemical, level: .medium, desc: "MSDS 미게시 화학물질 보관",
                   status: .inProgress, at: daysAgo(9), context: context, photo: false)
        seedHazard(siteId: siteC.id, inspection: inspC, location: "라인2 프레스",
                   type: .general, level: .high, desc: "프레스 방호덮개 인터록 불량",
                   status: .notStarted, at: daysAgo(1), context: context, photo: true)
        seedHazard(siteId: siteC.id, inspection: inspC, location: "라인2 배관",
                   type: .fire, level: .low, desc: "소화기 점검표 미기재",
                   status: .completed, at: daysAgo(20), context: context, photo: false)

        // MARK: Risk assessments — one per method
        seedThreeLevel(site: siteA, at: daysAgo(400), context: context)          // DUE (>1yr)
        seedFrequencySeverity(site: siteB, at: daysAgo(60), context: context)
        seedChecklistMethod(site: siteA, inspection: inspA, at: daysAgo(2), context: context)
        seedJSA(site: siteC, at: daysAgo(5), context: context)

        try? context.save()
    }

    // MARK: - Inspection builder

    @MainActor
    private static func makeInspection(
        site: Site, area: String, inspector: String,
        template: ChecklistTemplate?, startedAt: Date,
        context: ModelContext, itemCount: Int, failEvery: Int, photoEvery: Int
    ) -> Inspection {
        let insp = Inspection(siteId: site.id, siteName: site.name,
                              areaName: area, inspectorName: inspector,
                              templateId: template?.id ?? "korea-general-v1")
        insp.startedAt = startedAt
        insp.completedAt = startedAt.addingTimeInterval(45 * 60)
        insp.status = .completed
        context.insert(insp)

        // Flatten template (category, item) pairs, take the first `itemCount`.
        var pairs: [(cat: String, title: String, tid: String)] = []
        for cat in template?.categories ?? [] {
            for it in cat.items { pairs.append((cat.titleKey, it.titleKey, it.id)) }
        }
        if pairs.isEmpty {
            pairs = (0..<itemCount).map { ("checklist.category.commonSafety", "점검 항목 \($0 + 1)", "seed-\($0)") }
        }

        var order = 0
        for pair in pairs.prefix(itemCount) {
            let item = ChecklistItem(inspectionId: insp.id, templateItemId: pair.tid,
                                     title: pair.title, category: pair.cat, sortOrder: order)
            item.result = (order % failEvery == 0) ? .fail
                         : (order % 3 == 2 ? .notApplicable : .pass)
            if item.result == .fail { item.note = "재점검 필요 — 조치 후 확인" }
            if order % photoEvery == 0 { item.photoData = Self.seedPhotoMarker }
            context.insert(item)
            insp.items?.append(item)
            order += 1
        }
        return insp
    }

    @MainActor
    private static func seedHazard(
        siteId: UUID, inspection: Inspection, location: String, type: HazardType,
        level: RiskLevel, desc: String, status: CorrectiveActionStatus,
        at: Date, context: ModelContext, photo: Bool
    ) {
        let h = Hazard(siteId: siteId, location: location, type: type, riskLevel: level,
                       hazardDescription: desc, photoData: photo ? Self.seedPhotoMarker : nil,
                       inspectionId: inspection.id)
        h.correctiveActionStatus = status
        h.createdAt = at
        h.updatedAt = at
        context.insert(h)
        inspection.hazards?.append(h)
    }

    // MARK: - Risk assessments

    /// Builds a V3 assessment item and, when the seed row carries improvement data, its
    /// `CorrectiveAction` child (the fields that moved off the item in SCHEMA_V3 §4).
    /// Seed rows represent finalized assessments, so 초과여부 결정도 함께 기록한다.
    @MainActor
    private static func seedItem(
        _ context: ModelContext, ra: RiskAssessment,
        task: String, hazard: String, controls: String?,
        likelihood: Int? = nil, severity: Int? = nil, level: RiskLevel,
        measure: String? = nil, responsible: String? = nil, due: Date? = nil,
        sortOrder: Int
    ) -> RiskAssessmentItem {
        let it = RiskAssessmentItem(
            taskDescription: task, hazardDescription: hazard, currentControls: controls,
            likelihood: likelihood, severity: severity, riskLevel: level,
            sortOrder: sortOrder)
        // 초과여부 결정은 seedLockAndConfirm 에서 잠긴 기준 기반으로 확정한다(임의 주입 금지).
        it.riskAssessment = ra
        context.insert(it)
        // WO LEGAL-2c: 감소대책이 있을 때만, 봉인된 생성자(비공백 measure 필수)로 항상 .notStarted 조치를
        // 만든다. 상태 다양성은 시작(AssessmentStart.start) 이후 CorrectiveActionEditing.update로 부여한다.
        if let measure, let action = try? CorrectiveAction(item: it, measure: measure,
                                                           responsibleName: responsible, dueDate: due) {
            context.insert(action)
        }
        return it
    }

    /// Locks a default criteria (via the sanctioned atomic `AssessmentStart.start`) and confirms
    /// each seeded item's COMPUTED decision through the Core op — demo data goes through the same
    /// domain path as real input, never injecting an arbitrary decision (WO LEGAL-2b P1-1/P1-2).
    @MainActor
    private static func seedLockAndConfirm(_ context: ModelContext, ra: RiskAssessment, at: Date) {
        let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: ra.method.usesFrequencySeverity)
        try? AssessmentStart.start(ra, criteria: criteria, now: at, in: context)
        for it in ra.items ?? [] {
            try? it.confirmCriteriaDecision(under: criteria, at: at, by: ra.assessorName)
        }
        try? context.save()
    }

    @MainActor
    private static func seedThreeLevel(site: Site, at: Date, context: ModelContext) {
        let ra = RiskAssessment(kind: .regular, method: .threeLevel, siteId: site.id,
                                siteName: site.name, assessorName: "김안전")
        ra.assessedAt = at
        context.insert(ra)
        let rows: [(String, String, String, RiskLevel, String, String)] = [
            ("고소작업", "비계 단부 추락", "안전대 부착설비 설치", .high, "안전난간·작업발판 보강", "안전관리자"),
            ("전기작업", "활선 근접 감전", "정전작업 원칙, LOTO", .high, "검전·접지 절차 준수", "전기팀장"),
            ("중량물 취급", "인양물 낙하", "줄걸이 점검", .medium, "유도자 배치·통제구역", "작업반장"),
            ("용접작업", "화재·화상", "불티방지포 설치", .medium, "소화기 비치·화기감시자", "화기감시원"),
            ("정리정돈", "통로 걸림 전도", "자재 정위치 보관", .low, "일일 정리정돈 점검", "현장반장"),
            ("소음작업", "청력 손실", "귀마개 지급", .low, "정기 청력검사", "보건관리자"),
            ("밀폐공간", "산소결핍 질식", "환기·가스측정", .high, "감시인 배치·구조장비", "안전관리자"),
            ("차량계 장비", "협착·충돌", "후방감지기 점검", .medium, "유도자·서행 표지", "장비팀장"),
        ]
        ra.items = rows.enumerated().map { i, r in
            seedItem(context, ra: ra, task: r.0, hazard: r.1, controls: r.2, level: r.3,
                     measure: r.4, responsible: r.5,
                     due: at.addingTimeInterval(Double((i + 20) * 86400)), sortOrder: i)
        }
        seedLockAndConfirm(context, ra: ra, at: at)
    }

    @MainActor
    private static func seedFrequencySeverity(site: Site, at: Date, context: ModelContext) {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity, siteId: site.id,
                                siteName: site.name, assessorName: "이위험")
        ra.assessedAt = at
        context.insert(ra)
        let rows: [(String, String, String, Int, Int, String, String)] = [
            ("입고 하역", "지게차 협착", "보행자 통로 분리", 2, 3, "지게차 신호수 배치", "물류팀장"),
            ("적재 작업", "적재물 붕괴", "적재 높이 제한", 2, 2, "래킹 점검 주기화", "창고관리자"),
            ("컨베이어", "말림 재해", "비상정지 스위치", 1, 3, "방호덮개 보강", "설비팀장"),
            ("포장 작업", "반복동작 근골격", "작업대 높이 조절", 3, 1, "스트레칭·순환근무", "보건관리자"),
            ("냉동창고", "저온 노출", "방한복 지급", 2, 2, "체류시간 제한", "창고관리자"),
            ("상차 작업", "차량 후진 충돌", "후방감지·유도", 2, 3, "지정 유도자 배치", "물류팀장"),
            ("화학물 보관", "누출·흡입", "국소배기 설치", 1, 3, "MSDS 게시·훈련", "안전관리자"),
            ("전동 팔레트", "충돌·전도", "속도 제한", 2, 2, "통행로 표시", "설비팀장"),
            ("고소 선반", "추락", "이동식 사다리 점검", 1, 3, "안전대 사용", "창고관리자"),
            ("야간 작업", "조도 부족 전도", "조명 증설", 2, 1, "순찰 강화", "현장반장"),
            ("도크 셔터", "끼임·충돌", "센서 점검", 2, 2, "인터록 정기점검", "설비팀장"),
            ("리프트 작업", "낙하·추락", "안전벨트 확인", 2, 3, "정기 하중시험", "안전관리자"),
            ("파렛트 랙", "붕괴", "적재 하중 표시", 1, 3, "정기 안전진단", "창고관리자"),
            ("배터리 충전", "화재·폭발", "환기·전용구역", 1, 3, "충전구역 격리", "안전관리자"),
            ("수작업 분류", "근골격계 질환", "작업순환", 3, 1, "인간공학 개선", "보건관리자"),
            ("구내 통행", "차량 접촉", "보행로 분리", 2, 2, "속도제한 표지", "현장반장"),
        ]
        ra.items = rows.enumerated().map { i, r in
            let level = RiskMatrixConfig.threeByThree.band(likelihood: r.3, severity: r.4)
            return seedItem(context, ra: ra, task: r.0, hazard: r.1, controls: r.2,
                            likelihood: r.3, severity: r.4, level: level,
                            measure: r.5, responsible: r.6,
                            due: at.addingTimeInterval(Double((i + 15) * 86400)), sortOrder: i)
        }
        seedLockAndConfirm(context, ra: ra, at: at)
    }

    @MainActor
    private static func seedChecklistMethod(site: Site, inspection: Inspection, at: Date, context: ModelContext) {
        let ra = RiskAssessment(kind: .occasional, method: .checklist, siteId: site.id,
                                siteName: site.name, assessorName: "김안전",
                                linkedInspectionId: inspection.id)
        ra.assessedAt = at
        context.insert(ra)
        let rows: [(String, String, String, RiskLevel, String)] = [
            ("배전반 관리", "배전반 커버 파손 — 충전부 노출", "충전부 방호", .high, "커버 즉시 교체·잠금"),
            ("개구부 관리", "안전난간 미설치 개구부", "단부 방호", .high, "표준 안전난간 설치"),
            ("소화 설비", "소화기 점검표 미기재", "소화기 관리", .low, "점검표 부착·월점검"),
            ("정리정돈", "통로 자재 적치", "통로 확보", .low, "정위치 보관 지정"),
            ("보호구", "일부 미착용 관찰", "PPE 착용", .medium, "출입 시 착용 확인"),
            ("표지 관리", "위험 표지 훼손", "표지 정비", .medium, "훼손 표지 교체"),
        ]
        ra.items = rows.enumerated().map { i, r in
            seedItem(context, ra: ra, task: r.0, hazard: r.1, controls: r.2, level: r.3,
                     measure: r.4, responsible: "안전관리자",
                     due: at.addingTimeInterval(Double((i + 7) * 86400)), sortOrder: i)
        }
        seedLockAndConfirm(context, ra: ra, at: at)
        // 상태 다양성(demo): 생성자 우회 없이 — 시작 후 Core op로 짝수 항목 조치를 .inProgress 로.
        for it in (ra.items ?? []) where it.sortOrder % 2 == 0 {
            if let action = it.correctiveActions?.first, let m = action.measure {
                try? CorrectiveActionEditing.update(action, in: ra, measure: m, status: .inProgress,
                                                    at: at, context: context)
            }
        }
        try? context.save()
    }

    @MainActor
    private static func seedJSA(site: Site, at: Date, context: ModelContext) {
        let ra = RiskAssessment(kind: .regular, method: .jsa, siteId: site.id,
                                siteName: "\(site.name) — Line 2 Motor Replacement",
                                assessorName: "J. Park")
        ra.assessedAt = at
        context.insert(ra)
        let steps: [(String, String, String, Int, Int, String)] = [
            ("De-energize and lock out the line", "Unexpected energization / arc flash", "Verify zero energy; apply LOTO", 2, 3, "Second-person LOTO verification"),
            ("Barricade the work zone", "Struck by passing forklift", "Cones + exclusion tape", 2, 2, "Assign a spotter"),
            ("Set up access platform", "Fall from height", "Inspect ladder / scaffold", 2, 3, "Full-body harness + anchor"),
            ("Disconnect motor wiring", "Electric shock", "Confirm de-energized; insulated tools", 1, 3, "Test-before-touch"),
            ("Rig the motor for lifting", "Load drop / pinch point", "Inspect slings and shackles", 2, 3, "Tag line + no personnel under load"),
            ("Hoist out old motor", "Swinging load impact", "Slow, controlled lift", 2, 2, "Clear zone; use guide ropes"),
            ("Transport old motor", "Manual handling injury", "Use cart, not manual carry", 2, 1, "Team lift / mechanical aid"),
            ("Position new motor", "Crush between motor and frame", "Guided placement", 2, 3, "Keep hands clear; use bars"),
            ("Bolt down and align", "Hand injury from tools", "Correct torque tools", 1, 2, "Cut-resistant gloves"),
            ("Reconnect wiring", "Miswire / short", "Follow tagged terminals", 1, 3, "QA check before power"),
            ("Remove LOTO", "Premature start", "Confirm all clear", 2, 3, "Group lockout removal protocol"),
            ("Re-energize and test", "Arc flash on start", "Stand clear on first start", 1, 3, "PPE Cat-2; remote start"),
            ("Functional run check", "Rotating machinery contact", "Guards in place", 1, 3, "No loose clothing; barriers"),
            ("Housekeeping and sign-off", "Slip/trip on debris", "Clear tools and cables", 2, 1, "Final walk-through"),
        ]
        ra.items = steps.enumerated().map { i, s in
            let level = RiskMatrixConfig.threeByThree.band(likelihood: s.3, severity: s.4)
            return seedItem(context, ra: ra, task: s.0, hazard: s.1, controls: s.2,
                            likelihood: s.3, severity: s.4, level: level,
                            measure: s.5, sortOrder: i)
        }
        seedLockAndConfirm(context, ra: ra, at: at)
    }
}
#endif
