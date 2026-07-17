import Foundation
import SwiftUI
import SwiftData
import SafetyWalkCore

/// Orchestrates the 개선조치 편집 화면 (WO LEGAL-2c 2차): holds the draft fields, resolves + compresses
/// the evidence photo, and routes save / delete / 효과확인 through the atomic Core ops so the View does
/// not scatter persistence policy (CLAUDE.md MVVM). Status drives the lifecycle: a new action is always
/// `.notStarted`; 이행일·개선후위험도·사진·효과확인 exist only on a `.completed` action, and the editor
/// never lets status and 이행일 contradict. Compression failure and save failure surface distinctly.
@MainActor
@Observable
final class CorrectiveActionEditorViewModel {

    private let assessment: RiskAssessment
    private let item: RiskAssessmentItem
    let action: CorrectiveAction?          // nil = new

    // Editable fields
    var measure: String
    var responsibleName: String
    var hasDueDate: Bool
    var dueDate: Date
    var status: CorrectiveActionStatus
    var implementedAt: Date                // used only when status == .completed
    var postRiskLevel: RiskLevel?
    var effResultChoice: EffectivenessResult
    /// 효과 확인자 — 평가자와 다를 수 있으며 사용자가 수정한 값이 실제 `confirmedBy`가 된다.
    var confirmerName: String

    // Photo: a newly picked image (not yet compressed) OR the action's saved photo, or removed.
    var pickedImage: UIImage?
    private let existingPhotoData: Data?
    private(set) var photoRemoved = false

    // Distinct error surfacing (LEGAL-0: screen stays up on failure)
    var showSaveError = false
    var showCompressError = false

    /// Injected evidence-photo encoder (resize + JPEG). Defaults to `PhotoStorageService`; tests
    /// inject a stub to assert success/failure and CALL COUNT (new photo → 1, unchanged → 0).
    private let encode: (UIImage) throws -> Data

    init(assessment: RiskAssessment, item: RiskAssessmentItem, action: CorrectiveAction?,
         encode: @escaping (UIImage) throws -> Data = { try PhotoStorageService().data(from: $0) }) {
        self.assessment = assessment
        self.item = item
        self.action = action
        self.encode = encode
        self.measure = action?.measure ?? ""
        self.responsibleName = action?.responsibleName ?? ""
        self.hasDueDate = action?.dueDate != nil
        self.dueDate = action?.dueDate ?? Date()
        self.status = action?.status ?? .notStarted
        self.implementedAt = action?.implementedAt ?? Date()
        self.postRiskLevel = action?.postRiskLevel
        self.effResultChoice = action?.effectivenessResult ?? .effective
        // 기존 조치는 기존 확인자, 신규 확인은 평가자 이름을 편의상 prefill (사용자 수정 가능).
        self.confirmerName = action?.confirmedBy ?? assessment.assessorName
        self.existingPhotoData = action?.evidencePhotoData
    }

    // MARK: - Derived UI state

    var isNew: Bool { action == nil }
    var isEditable: Bool { CorrectiveActionPolicy.allowsCorrectiveActionEditing(assessment) }

    /// 이행일·개선후위험도·사진·효과확인은 완료 상태에서만 (상태·이행일 모순 차단). 최초 작성(new)은 항상
    /// 미착수라 완료-전용 필드를 아예 노출하지 않는다.
    var showsCompletedFields: Bool { !isNew && status == .completed }

    var canSave: Bool {
        isEditable && !measure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The photo to preview: a freshly picked image, else the (un-removed) saved photo.
    var displayPhoto: UIImage? {
        if let pickedImage { return pickedImage }
        if photoRemoved { return nil }
        return existingPhotoData.flatMap(UIImage.init(data:))
    }

    var hasPhoto: Bool {
        pickedImage != nil || (!photoRemoved && existingPhotoData != nil)
    }

    // 효과확인은 저장된 완료 상태(이행일·개선후위험도 포함)에서만. 저장 전 draft가 아니라 action을 읽는다.
    var canConfirmEffectiveness: Bool {
        guard isEditable, let action else { return false }
        return CorrectiveActionPolicy.isReadyForEffectivenessCheck(action)
    }
    /// The 효과확인 record button is enabled only when the action is ready AND the confirmer is non-blank
    /// (빈 확인자는 UI에서도 차단 — Core 도 emptyConfirmer 로 거부).
    var canRecordEffectiveness: Bool {
        canConfirmEffectiveness && !confirmerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var recordedEffectiveness: EffectivenessResult? { action?.effectivenessResult }
    var recordedConfirmer: String? { action?.confirmedBy }

    // MARK: - Photo mutations

    func setPickedImage(_ image: UIImage) {
        pickedImage = image
        photoRemoved = false
    }

    func removePhoto() {
        pickedImage = nil
        photoRemoved = true
    }

    /// The photo `Data` to persist: compresses a NEWLY picked image via `PhotoStorageService`
    /// (resize ≤1024px + JPEG); an unchanged existing photo is passed through WITHOUT re-compressing;
    /// a removed photo yields nil. Throws `PhotoStorageError.compressionFailed` on compression failure.
    private func resolvedPhotoData() throws -> Data? {
        if let pickedImage { return try encode(pickedImage) }   // compress ONLY the new photo
        if photoRemoved { return nil }
        return existingPhotoData                                // unchanged → no re-compress
    }

    // MARK: - Persistence (atomic Core ops)

    /// Returns true on success (the View then dismisses). Compression failure and save failure set
    /// their own flags so the screen can tell the two apart.
    func save(context: ModelContext) -> Bool {
        let trimmedMeasure = measure.trimmingCharacters(in: .whitespacesAndNewlines)
        let responsible = responsibleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let due = hasDueDate ? dueDate : nil

        let photoData: Data?
        do {
            photoData = try resolvedPhotoData()
        } catch {
            showCompressError = true
            return false
        }

        do {
            if let action {
                // Pass 이행일·개선후위험도 as-is — Core's CorrectiveActionPolicy.apply normalizes them to nil for a
                // non-completed status (single source for the "완료 전용 필드" rule).
                try CorrectiveActionEditing.update(
                    action, in: assessment, measure: trimmedMeasure,
                    responsibleName: responsible.isEmpty ? nil : responsible, dueDate: due,
                    status: status, implementedAt: implementedAt, postRiskLevel: postRiskLevel,
                    evidencePhotoData: photoData, at: Date(), context: context)
            } else {
                // A new action is always .notStarted (no status/이행일/개선후위험도/사진 at creation).
                try CorrectiveActionEditing.add(
                    to: item, in: assessment, measure: trimmedMeasure,
                    responsibleName: responsible.isEmpty ? nil : responsible, dueDate: due,
                    at: Date(), context: context)
            }
            return true
        } catch {
            showSaveError = true
            return false
        }
    }

    /// Records the 효과확인 (stays on screen to show the result). Returns success.
    @discardableResult
    func confirmEffectiveness(context: ModelContext) -> Bool {
        guard let action else { return false }
        do {
            try CorrectiveActionEditing.confirmEffectiveness(
                action, in: assessment, result: effResultChoice,
                by: confirmerName.trimmingCharacters(in: .whitespacesAndNewlines),
                at: Date(), context: context)
            return true
        } catch {
            showSaveError = true
            return false
        }
    }

    /// Deletes the action (the View confirms first). Returns success (then dismiss).
    func delete(context: ModelContext) -> Bool {
        guard let action else { return false }
        do {
            try CorrectiveActionEditing.remove(action, in: assessment, at: Date(), context: context)
            return true
        } catch {
            showSaveError = true
            return false
        }
    }
}
