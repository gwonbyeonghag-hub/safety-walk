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
        guard !assessorName.trimmingCharacters(in: .whitespaces).isEmpty,
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
    }

    func save(context: ModelContext) throws {
        // LEGAL-0 방어 guard: resolve every level BEFORE touching the context, so an
        // unassessed item aborts the save without leaving partial inserts. The normal
        // path is already gated by `canSave`; this makes 미평가 저장 impossible.
        let levels = try draftItems.map { d -> RiskLevel in
            guard let level = resolvedLevel(for: d) else { throw SaveError.incompleteItem }
            return level
        }

        let assessment = RiskAssessment(
            kind: kind,
            method: method,
            siteId: selectedSite?.id,
            siteName: selectedSite?.name ?? "",
            assessorName: assessorName.trimmingCharacters(in: .whitespaces),
            note: note.trimmedOrNil,
            linkedInspectionId: linkedInspectionId
        )
        context.insert(assessment)

        let isFreq = method.usesFrequencySeverity
        var items: [RiskAssessmentItem] = []
        for (index, d) in draftItems.enumerated() {
            let item = RiskAssessmentItem(
                taskDescription: d.taskDescription.trimmingCharacters(in: .whitespaces),
                hazardDescription: d.hazardDescription.trimmingCharacters(in: .whitespaces),
                currentControls: d.currentControls.trimmedOrNil,
                likelihood: isFreq ? d.likelihood : nil,
                severity: isFreq ? d.severity : nil,
                riskLevel: levels[index],
                reductionMeasure: d.reductionMeasure.trimmedOrNil,
                postRiskLevel: d.postRiskLevel,
                responsibleName: d.responsibleName.trimmedOrNil,
                dueDate: d.hasDueDate ? d.dueDate : nil,
                correctiveActionStatus: d.status,
                linkedHazardId: d.linkedHazardId,
                sortOrder: index
            )
            context.insert(item)
            items.append(item)
        }
        assessment.items = items

        // No `try?`: a failed save must propagate. Roll back the pending inserts so a
        // retry (screen stays up) doesn't double-insert the assessment.
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

private extension String {
    /// Trimmed, or nil when empty — keeps optional model fields truly optional.
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
