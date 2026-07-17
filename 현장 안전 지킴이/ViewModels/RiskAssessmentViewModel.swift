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
    var method: RiskAssessmentMethod = .frequencySeverity {
        didSet {
            // The acceptability threshold means different things for score vs. level methods
            // (raw score 2/4 vs. rank 1/2), so reset to the method default when the input
            // category flips — never carry an out-of-range value across (WO LEGAL-2b §3).
            if oldValue.usesFrequencySeverity != method.usesFrequencySeverity {
                criteriaThreshold = AcceptabilityCriteria
                    .makeDefault(usesFrequencySeverity: method.usesFrequencySeverity).threshold
            }
        }
    }
    var selectedSite: Site?
    var assessorName: String = ""
    var note: String = ""
    /// 허용 기준(acceptability) — the highest "기준 이내" score/rank, locked at start (WO LEGAL-2b).
    /// Default = 빈도×강도 2 (score). Reset on method-category change (see `method.didSet`).
    var criteriaThreshold: Int = 2
    /// Set when items were seeded from a completed Inspection (체크리스트법).
    var linkedInspectionId: UUID?

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
        var postRiskLevel: RiskLevel?   // 개선 후 위험성
        var responsibleName = ""        // 담당
        var hasDueDate = false
        var dueDate = Date()
        var status: CorrectiveActionStatus = .notStarted
        var linkedHazardId: UUID?       // carried over when seeded from a checklist item
    }

    // MARK: - Derived
    var canSave: Bool {
        // SCHEMA_V3 §4.1: a RiskAssessment requires a site (siteId·siteName). The Save button
        // stays disabled until one is chosen, same as an empty assessor name.
        guard selectedSite != nil,
              !assessorName.trimmingCharacters(in: .whitespaces).isEmpty,
              !draftItems.isEmpty else { return false }
        // LEGAL-0: every item must have a resolved 위험성 수준 (no 미평가 items may be saved).
        return draftItems.allSatisfy { resolvedLevel(for: $0) != nil }
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
    }

    func save(context: ModelContext) throws {
        // LEGAL-0 방어 guard: resolve every level BEFORE touching the context, so an
        // unassessed item aborts the save without leaving partial inserts. The normal
        // path is already gated by `canSave`; this makes 미평가 저장 impossible.
        let levels = try draftItems.map { d -> RiskLevel in
            guard let level = resolvedLevel(for: d) else { throw SaveError.incompleteItem }
            return level
        }
        // SCHEMA_V3 §4.1: siteId·siteName are required at construction (defence-in-depth).
        guard let site = selectedSite else { throw SaveError.missingSite }
        let isFreq = method.usesFrequencySeverity

        // Build the acceptability criteria BEFORE touching the context; an invalid threshold
        // aborts the whole save (fail-closed) rather than starting a half-built assessment.
        let criteria = try AcceptabilityCriteria
            .makeDefault(usesFrequencySeverity: isFreq)
            .withThreshold(criteriaThreshold)

        // Construct as .planned so both entry paths share the ONE start rule (WO LEGAL-2b §5):
        // this "assess now" flow immediately starts it via AssessmentStart, which locks the
        // criteria and flips it to .inProgress in a single atomic save.
        let assessment = RiskAssessment(
            kind: kind,
            method: method,
            siteId: site.id,
            siteName: site.name,
            assessorName: assessorName.trimmingCharacters(in: .whitespaces),
            note: note.trimmedOrNil,
            linkedInspectionId: linkedInspectionId
        )
        context.insert(assessment)

        var items: [RiskAssessmentItem] = []
        for (index, d) in draftItems.enumerated() {
            let item = RiskAssessmentItem(
                taskDescription: d.taskDescription.trimmingCharacters(in: .whitespaces),
                hazardDescription: d.hazardDescription.trimmingCharacters(in: .whitespaces),
                currentControls: d.currentControls.trimmedOrNil,
                likelihood: isFreq ? d.likelihood : nil,
                severity: isFreq ? d.severity : nil,
                riskLevel: levels[index],
                linkedHazardId: d.linkedHazardId,
                sortOrder: index
            )
            // criteriaDecision stays nil here — 기준 이내/초과 is confirmed by the user in detail,
            // never auto-filled at creation (WO LEGAL-2b §5/§6).
            context.insert(item)
            item.riskAssessment = assessment
            // The improvement fields moved off the item to CorrectiveAction (SCHEMA_V3 §4).
            // Persist whatever the user captured so nothing is silently dropped; the richer
            // corrective-action management UI (효과확인 등) is 2c.
            if let action = makeCorrectiveAction(from: d, item: item) {
                context.insert(action)
            }
            items.append(item)
        }
        assessment.items = items

        // Single atomic start: validate criteria → lock a value-copied snapshot → inProgress →
        // assessedAt/updatedAt → save (rolling back on any failure so the screen can retry).
        try AssessmentStart.start(assessment, criteria: criteria, now: Date(), in: context)
    }

    /// Builds a `CorrectiveAction` for the draft's improvement fields, or nil when there is no
    /// 감소대책(measure). WO LEGAL-2c 빈 개선조치 저장 금지: 감소대책 없는 조치는 만들지 않는다
    /// (measure = the corrective action's defining content — the same rule the 2c edit ops enforce).
    private func makeCorrectiveAction(from d: DraftItem, item: RiskAssessmentItem) -> CorrectiveAction? {
        guard let measure = d.reductionMeasure.trimmedOrNil else { return nil }
        return CorrectiveAction(
            item: item,
            measure: measure,
            responsibleName: d.responsibleName.trimmedOrNil,
            dueDate: d.hasDueDate ? d.dueDate : nil,
            status: d.status,
            postRiskLevel: d.postRiskLevel
        )
    }
}

private extension String {
    /// Trimmed, or nil when empty — keeps optional model fields truly optional.
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
