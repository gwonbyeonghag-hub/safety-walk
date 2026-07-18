import Foundation
import SwiftData
import Observation
import SafetyWalkCore

/// Drives the create flow for a 위험성평가 (Risk Assessment). Header fields plus a
/// list of in-progress `DraftItem`s; everything is committed to SwiftData in one
/// `save(context:)` at the end (mirrors StartInspectionViewModel).
@Observable
final class RiskAssessmentViewModel {

    // MARK: - Header
    var kind: RiskAssessmentKind = .regular
    var method: RiskAssessmentMethod = .frequencySeverity
    var selectedSite: Site?
    var assessorName: String = ""
    var note: String = ""
    /// Set when items were seeded from a completed Inspection (체크리스트법).
    var linkedInspectionId: UUID?
    /// 사용자가 확인한 법적 관할. **처음은 nil** — 지역 프로파일 추천이 자동으로 채우지 않는다
    /// (WO LEGAL-2d-PATH §3). 저장 전 반드시 선택돼야 한다.
    var jurisdiction: JurisdictionCode?
    /// KR 관할이면 필수인 평가 일정. 관할이 KR 이 아니면 무시된다.
    var scheduledAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    // MARK: - Draft items (value type until persisted; array order = sortOrder on save)
    var draftItems: [DraftItem] = []

    /// Matrix is data (CLAUDE.md): swapping to 5×5 later means a different config only.
    let matrix = RiskMatrixConfig.threeByThree

    init() {
        // Same person usually runs inspections and assessments — prefill from the
        // stored inspector name (the key SettingsView / OnboardingView write to).
        assessorName = UserDefaults.standard.string(forKey: "com.safetywalk.inspectorName") ?? ""
    }

    struct DraftItem: Identifiable, Equatable {
        var id = UUID()
        var taskDescription = ""        // 공정/작업
        var hazardDescription = ""      // 유해위험요인
        var currentControls = ""        // 현재 안전조치
        var likelihood: Int?            // 가능성 1–3 (빈도×강도)
        var severity: Int?              // 중대성 1–3 (빈도×강도)
        // LEGAL-0: nil = 미평가. The user must choose a level; nothing is auto-assigned.
        var directRiskLevel: RiskLevel?         // 3단계 직접 선택
        // 참고값 only — seeded from a linked hazard / checklist finding. Never auto-applied
        // to directRiskLevel; the user taps to confirm (LEGAL-0: 자동 확정 금지).
        var suggestedLevel: RiskLevel?
        var reductionMeasure = ""       // 감소대책
        var responsibleName = ""        // 담당
        var hasDueDate = false
        var dueDate = Date()
        // LEGAL-2c: 최초 작성 조치는 항상 .notStarted — 상태·이행일·개선후위험도·효과확인은 상세의
        // 개선조치 편집 화면에서만 다룬다. (그래서 여기엔 status/postRiskLevel 필드가 없다.)
        var linkedHazardId: UUID?       // carried over when seeded from a checklist item
    }

    // MARK: - Derived
    var canSave: Bool {
        // SCHEMA_V3 §4.1: a RiskAssessment requires a site (siteId·siteName). The Save button
        // stays disabled until one is chosen, same as an empty assessor name.
        guard selectedSite != nil,
              !assessorName.trimmingCharacters(in: .whitespaces).isEmpty,
              !draftItems.isEmpty else { return false }
        // WO LEGAL-2d-PATH §3: 관할은 저장 전 사용자가 명시적으로 확인해야 한다 — 추천만으로는 저장 불가.
        guard jurisdiction != nil else { return false }
        // LEGAL-0: every item must have a resolved 위험성 수준 (no 미평가 items may be saved).
        // 작업·유해위험요인은 Core 가 비공백을 요구하므로 화면도 같은 기준으로 막는다.
        return draftItems.allSatisfy { d in
            resolvedLevel(for: d) != nil
                && !d.taskDescription.trimmingCharacters(in: .whitespaces).isEmpty
                && !d.hazardDescription.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    /// Resolved 위험성 수준 for a draft under the current method, or `nil` when not yet
    /// assessed (LEGAL-0: 미입력은 등급 없음 — 색·점수·배지 미표시, 저장 불가).
    /// threeLevel → user's direct choice; frequencySeverity → derived from the matrix.
    func resolvedLevel(for item: DraftItem) -> RiskLevel? {
        guard method.usesFrequencySeverity else { return item.directRiskLevel }
        guard let l = item.likelihood, let s = item.severity else { return nil }
        return matrix.band(likelihood: l, severity: s)
    }

    /// Frequency×severity score for display (nil until both inputs chosen).
    func score(for item: DraftItem) -> Int? {
        guard let l = item.likelihood, let s = item.severity else { return nil }
        return matrix.score(likelihood: l, severity: s)
    }

    // MARK: - Draft mutations
    func addOrUpdate(_ item: DraftItem) {
        if let idx = draftItems.firstIndex(where: { $0.id == item.id }) {
            draftItems[idx] = item
        } else {
            draftItems.append(item)
        }
    }

    func deleteItems(at offsets: IndexSet) {
        // Remove high-to-low so earlier removals don't shift later indices.
        // (Avoids SwiftUI's remove(atOffsets:) so the ViewModel stays SwiftUI-free.)
        for index in offsets.sorted(by: >) {
            draftItems.remove(at: index)
        }
    }

    // MARK: - 체크리스트법: seed from a completed Inspection

    /// Seeds draft items from a completed inspection's **failed (부적합)** checklist
    /// items: the localized item title becomes the hazard, its category the task,
    /// any note the current control. A linked Hazard's level is carried as a
    /// `suggestedLevel` **참고값 only** — LEGAL-0 forbids auto-assigning a risk level,
    /// so `directRiskLevel` stays nil until the user confirms one.
    /// Template keys are resolved to literal text via `L(...)` (a text copy).
    func seedFromInspection(_ inspection: Inspection) {
        linkedInspectionId = inspection.id
        let hazardsById = Dictionary((inspection.hazards ?? []).map { ($0.id, $0) },
                                     uniquingKeysWith: { first, _ in first })
        let failItems = (inspection.items ?? [])
            .filter { $0.result == .fail }
            .sorted { $0.sortOrder < $1.sortOrder }
        for ci in failItems {
            var d = DraftItem()
            d.taskDescription = L(ci.category)
            d.hazardDescription = L(ci.title)
            d.currentControls = ci.note ?? ""
            d.linkedHazardId = ci.linkedHazardId
            // 참고값만: 연결된 위험요인의 기존 등급을 제안값으로. 자동 확정 금지 —
            // directRiskLevel은 nil로 두고 사용자가 확인해야 반영된다.
            if let hid = ci.linkedHazardId, let hz = hazardsById[hid] {
                d.suggestedLevel = hz.riskLevel
            }
            draftItems.append(d)
        }
    }

    // MARK: - Persist

    /// Thrown when persistence cannot complete. LEGAL-0: save() never fails silently —
    /// it throws so the caller can keep the screen up and surface an error.
    enum SaveError: Error {
        case incompleteItem   // a draft item has no resolved 위험성 수준 (defence-in-depth; canSave gates this)
        case missingSite      // SCHEMA_V3 §4.1: RiskAssessment requires a site (canSave gates this)
        case incompleteAction // LEGAL-2c: 개선조치 필드(담당/기한)만 있고 감소대책이 비어 있음
    }

    /// 평가를 **`.planned` 로** 저장한다 (WO LEGAL-2d-PATH §2).
    ///
    /// 옛 "저장하자마자 `AssessmentStart` 호출" 경로는 제거됐다 — 이제 두 생성 경로가 똑같이 planned
    /// 평가를 만들고, 시작(기준 잠금 → `.inProgress`)은 상세 화면에서 따로 한다. 그래야 KR 처럼 시작 전
    /// 사전 공유가 필요한 관할에서 "저장은 됐는데 시작이 막혀 반쯤 만들어진 평가"가 생기지 않는다.
    ///
    /// 검증·insert·commit 은 전부 Core 의 단일 원자 연산이 담당한다 — 실패하면 store 와 메모리 어디에도
    /// 평가·항목·조치가 남지 않으므로, 화면은 그대로 두고 다시 시도할 수 있다.
    func save(context: ModelContext) throws {
        guard let site = selectedSite else { throw SaveError.missingSite }
        let draft = AssessmentDraft(
            kind: kind,
            method: method,
            siteId: site.id,
            siteName: site.name,
            assessorName: assessorName,
            note: note.trimmedOrNil,
            linkedInspectionId: linkedInspectionId,
            jurisdiction: jurisdiction,
            scheduledAt: JurisdictionPolicy.requiresSchedule(jurisdiction) ? scheduledAt : nil,
            items: draftItems.map { d in
                AssessmentDraft.ItemDraft(
                    taskDescription: d.taskDescription,
                    hazardDescription: d.hazardDescription,
                    currentControls: d.currentControls.trimmedOrNil,
                    likelihood: d.likelihood,
                    severity: d.severity,
                    riskLevel: resolvedLevel(for: d),
                    linkedHazardId: d.linkedHazardId,
                    measure: d.reductionMeasure.trimmedOrNil,
                    responsibleName: d.responsibleName.trimmedOrNil,
                    dueDate: d.hasDueDate ? d.dueDate : nil)
            })
        try AssessmentAuthoring.create(draft, now: Date(), in: context)
    }
}

private extension String {
    /// Trimmed, or nil when empty — keeps optional model fields truly optional.
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
