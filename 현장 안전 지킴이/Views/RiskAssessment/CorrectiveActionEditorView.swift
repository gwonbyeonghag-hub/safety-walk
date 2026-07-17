import SwiftUI
import SafetyWalkCore
import PhotosUI

/// depth-3 editor (pushed from `CorrectiveActionListView`): create or edit ONE 개선조치, plus the
/// separate 효과확인 step (WO LEGAL-2c). All writes go through the atomic Core ops
/// (`CorrectiveActionEditing`), which validate (빈 조치 차단), persist with a store+memory restore on
/// failure, and reset the 효과확인 when a substantive field changes. The evidence photo lives in
/// local state and is written to the model ONLY on save (사진은 확정 저장 시에만 반영). A cancelled
/// assessment renders read-only. Effectiveness needs its 이행일·개선후위험도 preconditions persisted,
/// so it is offered on an existing action whose implementation is already recorded.
struct CorrectiveActionEditorView: View {
    let assessment: RiskAssessment
    let item: RiskAssessmentItem
    let action: CorrectiveAction?          // nil = new

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Editable fields
    @State private var measure: String
    @State private var responsibleName: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var status: CorrectiveActionStatus
    @State private var hasImplementedAt: Bool
    @State private var implementedAt: Date
    @State private var postRiskLevel: RiskLevel?
    @State private var photoData: Data?

    // Photo picker
    @State private var pickerItem: PhotosPickerItem?
    // 효과확인
    @State private var effResultChoice: EffectivenessResult
    // Error surfacing (LEGAL-0: screen stays up on failure)
    @State private var showSaveError = false
    @State private var showPhotoError = false

    init(assessment: RiskAssessment, item: RiskAssessmentItem, action: CorrectiveAction?) {
        self.assessment = assessment
        self.item = item
        self.action = action
        _measure = State(initialValue: action?.measure ?? "")
        _responsibleName = State(initialValue: action?.responsibleName ?? "")
        _hasDueDate = State(initialValue: action?.dueDate != nil)
        _dueDate = State(initialValue: action?.dueDate ?? Date())
        _status = State(initialValue: action?.status ?? .notStarted)
        _hasImplementedAt = State(initialValue: action?.implementedAt != nil)
        _implementedAt = State(initialValue: action?.implementedAt ?? Date())
        _postRiskLevel = State(initialValue: action?.postRiskLevel)
        _photoData = State(initialValue: action?.evidencePhotoData)
        _effResultChoice = State(initialValue: action?.effectivenessResult ?? .effective)
    }

    /// 개선조치는 finalized 후에도 수정 가능; cancelled(및 planned)는 읽기 전용.
    private var isEditable: Bool { assessment.allowsCorrectiveActionEditing }

    private var canSave: Bool {
        isEditable && !measure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            planSection
            fieldsSection
            implementationSection
            effectivenessSection
            if action != nil, isEditable { deleteSection }
        }
        .disabled(!isEditable)
        .navigationTitle((action == nil ? LocalizationKey.raActionNew : LocalizationKey.raActionEdit).localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditable {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonSave.localized) { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("ra_action_save")
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    photoData = data
                } else {
                    showPhotoError = true
                }
            }
        }
        .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $showSaveError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.raSaveFailedMessage.localized)
        }
        .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $showPhotoError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.raSaveFailedMessage.localized)
        }
    }

    // MARK: - Sections

    /// Reminds the user this item exceeds the criteria (context for why a 개선조치 is required).
    @ViewBuilder private var planSection: some View {
        if item.needsCorrectiveActionPlan {
            Section {
                Label(LocalizationKey.raActionPlanRequired.localized, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fieldsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizationKey.raItemReduction.localized)
                    .font(.caption).foregroundStyle(.secondary)
                TextField(LocalizationKey.raItemReduction.localized, text: $measure, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityIdentifier("ra_action_measure")
                if measure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(LocalizationKey.raActionMeasureRequired.localized)
                        .font(.caption2).foregroundStyle(.red)
                }
            }
            TextField(LocalizationKey.raItemResponsible.localized, text: $responsibleName)
            Toggle(LocalizationKey.raItemSetDueDate.localized, isOn: $hasDueDate)
            if hasDueDate {
                DatePicker(LocalizationKey.raItemDueDate.localized, selection: $dueDate, displayedComponents: .date)
            }
            Picker(LocalizationKey.raItemStatus.localized, selection: $status) {
                ForEach(CorrectiveActionStatus.allCases, id: \.self) { s in
                    Text(s.localizedLabel).tag(s)
                }
            }
        }
    }

    private var implementationSection: some View {
        Section(LocalizationKey.raActionImplementedAt.localized) {
            Toggle(LocalizationKey.raActionSetImplementedAt.localized, isOn: $hasImplementedAt)
            if hasImplementedAt {
                DatePicker(LocalizationKey.raActionImplementedAt.localized,
                           selection: $implementedAt, displayedComponents: .date)
            }
            Picker(LocalizationKey.raItemPostRiskLevel.localized, selection: $postRiskLevel) {
                Text(LocalizationKey.raRiskUnassessed.localized).tag(RiskLevel?.none)
                ForEach(RiskLevel.allCases, id: \.self) { level in
                    Text(level.localizedLabel).tag(RiskLevel?.some(level))
                }
            }
            photoRow
        }
    }

    @ViewBuilder private var photoRow: some View {
        if let data = photoData, let uiImage = UIImage(data: data) {
            HStack {
                Image(uiImage: uiImage)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)   // the adjacent label names it
                Text(LocalizationKey.raActionEvidencePhoto.localized)
                    .font(.subheadline)
                Spacer()
                if isEditable {
                    Button(role: .destructive) { photoData = nil; pickerItem = nil } label: {
                        Image(systemName: "trash").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        if isEditable {
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Label(photoData == nil ? LocalizationKey.checklistAttachPhoto.localized
                                       : LocalizationKey.checklistReplacePhoto.localized,
                      systemImage: photoData == nil ? "camera" : "arrow.triangle.2.circlepath")
                    .frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("ra_action_photo_picker")
        }
    }

    /// 효과확인 — offered only on an EXISTING action; the 이행일·개선후위험도 preconditions must already
    /// be persisted (the Core op enforces them, so the button is gated on the saved action's state).
    @ViewBuilder private var effectivenessSection: some View {
        if let action {
            Section(LocalizationKey.raActionEffSection.localized) {
                if let result = action.effectivenessResult {
                    HStack {
                        Label(result.localizedLabel, systemImage: result.systemImage)
                            .font(.subheadline)
                        Spacer()
                    }
                    if let by = action.confirmedBy, !by.isEmpty {
                        Text(String(format: LocalizationKey.raActionEffConfirmedFmt.localized, by))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if isEditable {
                    if action.implementedAt != nil && action.postRiskLevel != nil {
                        Picker(LocalizationKey.raActionEffResult.localized, selection: $effResultChoice) {
                            ForEach(EffectivenessResult.allCases) { r in
                                Text(r.localizedLabel).tag(r)
                            }
                        }
                        Button(LocalizationKey.raActionEffConfirm.localized) { confirmEffectiveness() }
                            .accessibilityIdentifier("ra_action_confirm_effectiveness")
                    } else {
                        Text(LocalizationKey.raActionEffHint.localized)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) { deleteAction() } label: {
                Label(LocalizationKey.commonDelete.localized, systemImage: "trash")
            }
            .accessibilityIdentifier("ra_action_delete")
        }
    }

    // MARK: - Actions (all via the atomic Core ops)

    private func save() {
        let trimmedMeasure = measure.trimmingCharacters(in: .whitespacesAndNewlines)
        let responsible = responsibleName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let action {
                try CorrectiveActionEditing.update(
                    action, in: assessment, measure: trimmedMeasure,
                    responsibleName: responsible.isEmpty ? nil : responsible,
                    dueDate: hasDueDate ? dueDate : nil, status: status,
                    implementedAt: hasImplementedAt ? implementedAt : nil,
                    postRiskLevel: postRiskLevel, evidencePhotoData: photoData,
                    at: Date(), context: modelContext)
            } else {
                try CorrectiveActionEditing.add(
                    to: item, in: assessment, measure: trimmedMeasure,
                    responsibleName: responsible.isEmpty ? nil : responsible,
                    dueDate: hasDueDate ? dueDate : nil, status: status,
                    implementedAt: hasImplementedAt ? implementedAt : nil,
                    postRiskLevel: postRiskLevel, evidencePhotoData: photoData,
                    at: Date(), context: modelContext)
            }
            dismiss()
        } catch {
            showSaveError = true
        }
    }

    private func confirmEffectiveness() {
        guard let action else { return }
        do {
            try CorrectiveActionEditing.confirmEffectiveness(
                action, in: assessment, result: effResultChoice,
                by: assessment.assessorName, at: Date(), context: modelContext)
        } catch {
            showSaveError = true
        }
    }

    private func deleteAction() {
        guard let action else { return }
        do {
            try CorrectiveActionEditing.remove(action, in: assessment, at: Date(), context: modelContext)
            dismiss()
        } catch {
            showSaveError = true
        }
    }
}
