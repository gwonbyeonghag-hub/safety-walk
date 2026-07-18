import SwiftUI
import SwiftData
import SafetyWalkCore

/// Sheet root for creating a 위험성평가. Header (kind / method / site / assessor)
/// plus an items section; "저장" commits the whole assessment to SwiftData.
struct RiskAssessmentCreateView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Site.name) private var sites: [Site]
    @State private var viewModel = RiskAssessmentViewModel()
    @State private var editorItem: RiskAssessmentViewModel.DraftItem?
    @State private var showInspectionPicker = false
    // 추천 문구 전용 — 저장 접근은 RegionProfileStore 만 사용한다.
    private let regionProfile = RegionProfileStore.get()
    @State private var showSaveError = false
    @State private var saveErrorMessage = LocalizationKey.raSaveFailedMessage.localized

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizationKey.raKind.localized) {
                    Picker(LocalizationKey.raKind.localized, selection: $viewModel.kind) {
                        ForEach(RiskAssessmentKind.allCases) { k in
                            Text(k.localizedLabel).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section(LocalizationKey.raMethod.localized) {
                    // 4 methods → menu (segmented is too cramped for the labels).
                    Picker(LocalizationKey.raMethod.localized, selection: $viewModel.method) {
                        ForEach(RiskAssessmentMethod.allCases) { m in
                            Text(m.localizedLabel).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityIdentifier("ra_method_picker")
                }

                Section {
                    sitePicker
                    HStack {
                        Text(LocalizationKey.raAssessor.localized)
                        Spacer()
                        TextField(LocalizationKey.raAssessorPlaceholder.localized,
                                  text: $viewModel.assessorName)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField(LocalizationKey.raNote.localized, text: $viewModel.note, axis: .vertical)
                        .lineLimit(1...3)
                }

                // WO LEGAL-2d-PATH §2: 생성은 planned 까지만 — 허용 기준은 **시작할 때** 잠기므로
                // 여기서 고르지 않는다(상세의 시작 시트가 담당). 관할은 저장 전 사용자가 확인해야 한다.
                JurisdictionSection(jurisdiction: $viewModel.jurisdiction,
                                    regionProfile: regionProfile)

                if JurisdictionPolicy.requiresSchedule(viewModel.jurisdiction) {
                    Section {
                        DatePicker(LocalizationKey.raSchedule.localized,
                                   selection: $viewModel.scheduledAt, displayedComponents: .date)
                            .accessibilityIdentifier("ra_scheduled_date")
                    }
                }

                itemsSection
            }
            .navigationTitle(LocalizationKey.raNew.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonSave.localized) {
                        // LEGAL-0: never dismiss on a silent failure — save() throws,
                        // and we only leave the screen once it actually persisted. LEGAL-2c:
                        // a partial 개선조치 (담당/기한 without 감소대책) gets a specific validation message.
                        do {
                            try viewModel.save(context: modelContext)
                            dismiss()
                        } catch RiskAssessmentViewModel.SaveError.incompleteAction {
                            saveErrorMessage = LocalizationKey.raActionMeasureRequired.localized
                            showSaveError = true
                        } catch {
                            saveErrorMessage = LocalizationKey.raSaveFailedMessage.localized
                            showSaveError = true
                        }
                    }
                    .disabled(saveDisabled)
                }
            }
            .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $showSaveError) {
                Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
            .sheet(item: $editorItem) { draft in
                RiskAssessmentItemEditorView(
                    method: viewModel.method,
                    matrix: viewModel.matrix,
                    draft: draft
                ) { updated in
                    // 생성 화면은 초안만 모은다(영속은 저장 시 한 번) — 실패할 여지가 없으므로 항상 성공.
                    viewModel.addOrUpdate(updated)
                    return true
                }
            }
            .sheet(isPresented: $showInspectionPicker) {
                InspectionSeedPickerView { inspection in
                    viewModel.seedFromInspection(inspection)
                    if viewModel.selectedSite == nil {
                        viewModel.selectedSite = sites.first { $0.id == inspection.siteId }
                    }
                }
            }
        }
    }

    // MARK: - Site picker (optional) — Menu avoids @Model Picker-tag identity issues

    private var sitePicker: some View {
        Menu {
            Button(LocalizationKey.raSiteNone.localized) { viewModel.selectedSite = nil }
            ForEach(sites) { site in
                Button(site.name) { viewModel.selectedSite = site }
            }
        } label: {
            HStack {
                Text(LocalizationKey.raSite.localized)
                    .foregroundStyle(.primary)
                Spacer()
                Text(viewModel.selectedSite?.name ?? LocalizationKey.raSiteNone.localized)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityIdentifier("ra_site_picker")
    }

    // MARK: - Items

    private var itemsSection: some View {
        Section(LocalizationKey.raItemsSection.localized) {
            // 체크리스트법: seed failed (부적합) items from a completed inspection.
            if viewModel.method == .checklist {
                Button {
                    showInspectionPicker = true
                } label: {
                    Label(LocalizationKey.raSeedFromInspection.localized,
                          systemImage: "square.and.arrow.down")
                }
            }

            if viewModel.draftItems.isEmpty {
                Text(LocalizationKey.raItemsEmpty.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.draftItems.enumerated()), id: \.element.id) { index, item in
                    Button {
                        editorItem = item
                    } label: {
                        DraftItemRow(item: item,
                                     level: viewModel.resolvedLevel(for: item),
                                     stepNumber: viewModel.method == .jsa ? index + 1 : nil)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { viewModel.deleteItems(at: $0) }
            }

            Button {
                editorItem = RiskAssessmentViewModel.DraftItem()
            } label: {
                Label(viewModel.method == .jsa ? LocalizationKey.raJsaAddStep.localized
                                               : LocalizationKey.raItemAdd.localized,
                      systemImage: "plus.circle.fill")
            }

            // LEGAL-0: tell the user why 저장 is disabled when an item is 미평가.
            if hasUnassessedItem {
                Label(LocalizationKey.raSaveIncompleteHint.localized, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("ra_incomplete_hint")
            }
        }
    }

    /// True when at least one draft item still has no resolved 위험성 수준 (미평가).
    private var hasUnassessedItem: Bool {
        !viewModel.draftItems.isEmpty
            && viewModel.draftItems.contains { viewModel.resolvedLevel(for: $0) == nil }
    }

    /// Normally `!canSave`. A DEBUG-only UI-test flag lets a test tap 저장 on an
    /// incomplete assessment so the REAL guard-throw → 저장 실패 alert can be captured
    /// (mirrors the app's other DEBUG-gated uitest hooks; stripped from Release).
    private var saveDisabled: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-com.safetywalk.uitestAllowIncompleteSave") {
            return false
        }
        #endif
        return !viewModel.canSave
    }
}

/// Compact row for a draft item (create flow): title + resolved risk band, or a
/// neutral "미평가" placeholder when the risk level is not yet set (LEGAL-0).
private struct DraftItemRow: View {
    let item: RiskAssessmentViewModel.DraftItem
    let level: RiskLevel?
    var stepNumber: Int? = nil

    private var title: String {
        let t = item.taskDescription.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { return t }
        let h = item.hazardDescription.trimmingCharacters(in: .whitespaces)
        return h.isEmpty ? "—" : h
    }

    var body: some View {
        HStack(spacing: 10) {
            if let n = stepNumber {
                Text("\(n)")
                    .font(.caption2.weight(.bold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color.secondary, in: Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !item.hazardDescription.trimmingCharacters(in: .whitespaces).isEmpty,
                   !item.taskDescription.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(item.hazardDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let level {
                RiskChip(level: level)
            } else {
                UnassessedChip()
            }
        }
    }
}

/// Neutral "미평가" placeholder — no risk color, no score, no band badge (LEGAL-0:
/// an unentered risk level must not read as any level).
private struct UnassessedChip: View {
    var body: some View {
        Text(LocalizationKey.raRiskUnassessed.localized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(Color.secondary.opacity(0.12))
            }
            .overlay {
                Capsule().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 0.5)
            }
            .accessibilityLabel(LocalizationKey.raRiskUnassessed.localized)
            .accessibilityIdentifier("ra_unassessed_chip")
    }
}
