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
                    Picker(LocalizationKey.raMethod.localized, selection: $viewModel.method) {
                        ForEach(RiskAssessmentMethod.allCases) { m in
                            Text(m.localizedLabel).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
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
                        viewModel.save(context: modelContext)
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .sheet(item: $editorItem) { draft in
                RiskAssessmentItemEditorView(
                    method: viewModel.method,
                    matrix: viewModel.matrix,
                    draft: draft
                ) { updated in
                    viewModel.addOrUpdate(updated)
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
    }

    // MARK: - Items

    private var itemsSection: some View {
        Section(LocalizationKey.raItemsSection.localized) {
            if viewModel.draftItems.isEmpty {
                Text(LocalizationKey.raItemsEmpty.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.draftItems) { item in
                    Button {
                        editorItem = item
                    } label: {
                        DraftItemRow(item: item, level: viewModel.resolvedLevel(for: item))
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { viewModel.deleteItems(at: $0) }
            }

            Button {
                editorItem = RiskAssessmentViewModel.DraftItem()
            } label: {
                Label(LocalizationKey.raItemAdd.localized, systemImage: "plus.circle.fill")
            }
        }
    }
}

/// Compact row for a draft item (create flow): title + resolved risk band.
private struct DraftItemRow: View {
    let item: RiskAssessmentViewModel.DraftItem
    let level: RiskLevel

    private var title: String {
        let t = item.taskDescription.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { return t }
        let h = item.hazardDescription.trimmingCharacters(in: .whitespaces)
        return h.isEmpty ? "—" : h
    }

    var body: some View {
        HStack(spacing: 10) {
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
            RiskBandChip(level: level)
        }
    }
}
