import SwiftUI
import SafetyWalkCore
import PhotosUI

/// depth-3 editor (pushed from `CorrectiveActionListView`): create or edit ONE 개선조치, plus the
/// separate 효과확인 step (WO LEGAL-2c). Thin over `CorrectiveActionEditorViewModel`, which owns all
/// save/delete/효과확인 orchestration + photo compression (CLAUDE.md MVVM). Status drives the UI: a
/// new action captures only 감소대책·담당·기한 (always .notStarted); the 이행일·개선후위험도·사진·효과확인
/// lifecycle appears only once an existing action is marked 완료, so status and 이행일 can't contradict.
/// A cancelled assessment renders read-only.
struct CorrectiveActionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm: CorrectiveActionEditorViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showDeleteConfirm = false

    let needsPlan: Bool

    init(assessment: RiskAssessment, item: RiskAssessmentItem, action: CorrectiveAction?) {
        _vm = State(initialValue: CorrectiveActionEditorViewModel(assessment: assessment, item: item, action: action))
        self.needsPlan = item.needsCorrectiveActionPlan
    }

    var body: some View {
        Form {
            planSection
            fieldsSection
            if !vm.isNew { statusSection }
            if vm.showsCompletedFields { completionSection }
            if !vm.isNew { effectivenessSection }
            if !vm.isNew, vm.isEditable { deleteSection }
        }
        .disabled(!vm.isEditable)
        .navigationTitle((vm.isNew ? LocalizationKey.raActionNew : LocalizationKey.raActionEdit).localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.isEditable {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonSave.localized) {
                        if vm.save(context: modelContext) { dismiss() }
                    }
                    .disabled(!vm.canSave)
                    .accessibilityIdentifier("ra_action_save")
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    vm.showCompressError = true    // decode failure surfaces like a photo failure
                    return
                }
                vm.setPickedImage(image)
            }
        }
        .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $vm.showSaveError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.raSaveFailedMessage.localized)
        }
        .alert(LocalizationKey.raActionPhotoFailedTitle.localized, isPresented: $vm.showCompressError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.raActionPhotoFailedMessage.localized)
        }
        .confirmationDialog(LocalizationKey.raActionDeleteConfirm.localized,
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(LocalizationKey.commonDelete.localized, role: .destructive) {
                if vm.delete(context: modelContext) { dismiss() }
            }
            Button(LocalizationKey.commonCancel.localized, role: .cancel) { }
        }
    }

    // MARK: - Sections

    @ViewBuilder private var planSection: some View {
        if needsPlan {
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
                TextField(LocalizationKey.raItemReduction.localized, text: $vm.measure, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityIdentifier("ra_action_measure")
                if vm.measure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(LocalizationKey.raActionMeasureRequired.localized)
                        .font(.caption2).foregroundStyle(.red)
                }
            }
            TextField(LocalizationKey.raItemResponsible.localized, text: $vm.responsibleName)
            Toggle(LocalizationKey.raItemSetDueDate.localized, isOn: $vm.hasDueDate)
            if vm.hasDueDate {
                DatePicker(LocalizationKey.raItemDueDate.localized, selection: $vm.dueDate, displayedComponents: .date)
            }
        }
    }

    private var statusSection: some View {
        Section {
            Picker(LocalizationKey.raItemStatus.localized, selection: $vm.status) {
                ForEach(CorrectiveActionStatus.allCases, id: \.self) { s in
                    Text(s.localizedLabel).tag(s)
                }
            }
            .accessibilityIdentifier("ra_action_status")
        }
    }

    /// 완료 상태에서만: 이행일(기본 오늘)·개선후위험도·증거사진. 상태와 이행일이 모순될 수 없다.
    private var completionSection: some View {
        Section(LocalizationKey.raActionImplementedAt.localized) {
            DatePicker(LocalizationKey.raActionImplementedAt.localized,
                       selection: $vm.implementedAt, displayedComponents: .date)
            Picker(LocalizationKey.raItemPostRiskLevel.localized, selection: $vm.postRiskLevel) {
                Text(LocalizationKey.raRiskUnassessed.localized).tag(RiskLevel?.none)
                ForEach(RiskLevel.allCases, id: \.self) { level in
                    Text(level.localizedLabel).tag(RiskLevel?.some(level))
                }
            }
            photoRow
        }
    }

    @ViewBuilder private var photoRow: some View {
        if let image = vm.displayPhoto {
            HStack {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)
                Text(LocalizationKey.raActionEvidencePhoto.localized)
                    .font(.subheadline)
                Spacer()
                Button(role: .destructive) { vm.removePhoto() } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)          // ≥44×44pt touch target
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(LocalizationKey.commonDelete.localized)
            }
        }
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            Label(vm.hasPhoto ? LocalizationKey.checklistReplacePhoto.localized
                              : LocalizationKey.checklistAttachPhoto.localized,
                  systemImage: vm.hasPhoto ? "arrow.triangle.2.circlepath" : "camera")
                .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("ra_action_photo_picker")
    }

    /// 효과확인 — 존재하는 조치에서만. 저장된 완료 상태(이행일·개선후위험도)일 때만 기록 버튼이 활성화된다.
    @ViewBuilder private var effectivenessSection: some View {
        Section(LocalizationKey.raActionEffSection.localized) {
            if let result = vm.recordedEffectiveness {
                HStack {
                    Label(result.localizedLabel, systemImage: result.systemImage)
                        .font(.subheadline)
                    Spacer()
                }
                if let by = vm.recordedConfirmer, !by.isEmpty {
                    Text(String(format: LocalizationKey.raActionEffConfirmedFmt.localized, by))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if vm.canConfirmEffectiveness {
                Picker(LocalizationKey.raActionEffResult.localized, selection: $vm.effResultChoice) {
                    ForEach(EffectivenessResult.allCases) { r in
                        Text(r.localizedLabel).tag(r)
                    }
                }
                Button(LocalizationKey.raActionEffConfirm.localized) {
                    vm.confirmEffectiveness(context: modelContext)
                }
                .accessibilityIdentifier("ra_action_confirm_effectiveness")
            } else if vm.isEditable, vm.recordedEffectiveness == nil {
                Text(LocalizationKey.raActionEffHint.localized)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label(LocalizationKey.commonDelete.localized, systemImage: "trash")
            }
            .accessibilityIdentifier("ra_action_delete")
        }
    }
}
