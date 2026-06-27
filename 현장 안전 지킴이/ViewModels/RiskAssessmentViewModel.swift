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

    // MARK: - Draft items (value type until persisted)
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
        var directRiskLevel: RiskLevel = .low   // 3단계 직접 선택
        var reductionMeasure = ""       // 감소대책
        var postRiskLevel: RiskLevel?   // 개선 후 위험성
        var responsibleName = ""        // 담당
        var hasDueDate = false
        var dueDate = Date()
        var status: CorrectiveActionStatus = .notStarted
    }

    // MARK: - Derived
    var canSave: Bool {
        !assessorName.trimmingCharacters(in: .whitespaces).isEmpty && !draftItems.isEmpty
    }

    /// Resolved 위험성 수준 for a draft under the current method.
    /// threeLevel → user's direct choice; frequencySeverity → derived from the matrix.
    func resolvedLevel(for item: DraftItem) -> RiskLevel {
        switch method {
        case .threeLevel:
            return item.directRiskLevel
        case .frequencySeverity:
            guard let l = item.likelihood, let s = item.severity else { return .low }
            return matrix.band(likelihood: l, severity: s)
        }
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

    // MARK: - Persist
    func save(context: ModelContext) {
        let assessment = RiskAssessment(
            kind: kind,
            method: method,
            siteId: selectedSite?.id,
            siteName: selectedSite?.name ?? "",
            assessorName: assessorName.trimmingCharacters(in: .whitespaces),
            note: note.trimmedOrNil
        )
        context.insert(assessment)

        let isFreq = (method == .frequencySeverity)
        var items: [RiskAssessmentItem] = []
        for d in draftItems {
            let item = RiskAssessmentItem(
                taskDescription: d.taskDescription.trimmingCharacters(in: .whitespaces),
                hazardDescription: d.hazardDescription.trimmingCharacters(in: .whitespaces),
                currentControls: d.currentControls.trimmedOrNil,
                likelihood: isFreq ? d.likelihood : nil,
                severity: isFreq ? d.severity : nil,
                riskLevel: resolvedLevel(for: d),
                reductionMeasure: d.reductionMeasure.trimmedOrNil,
                postRiskLevel: d.postRiskLevel,
                responsibleName: d.responsibleName.trimmedOrNil,
                dueDate: d.hasDueDate ? d.dueDate : nil,
                correctiveActionStatus: d.status
            )
            context.insert(item)
            items.append(item)
        }
        assessment.items = items

        try? context.save()
    }
}

private extension String {
    /// Trimmed, or nil when empty — keeps optional model fields truly optional.
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
