import SwiftUI
import SafetyWalkCore
import SwiftData

/// Final step of the Start Inspection flow. The inspector picks which template
/// categories are in scope for this inspection. Only selected categories
/// produce ChecklistItem records; unselected categories are excluded entirely
/// (different from N/A, which is a per-item judgment on an included item).
///
/// Reads `viewModel.selectedTemplate` from the Environment. No @Query (the
/// template is a JSON-loaded struct on the viewModel; nothing to fetch).
struct InspectionScopeSelectionView: View {

    @Binding var isDone: Bool
    @Environment(StartInspectionViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext

    private var template: ChecklistTemplate? { viewModel.selectedTemplate }

    var body: some View {
        VStack(spacing: 0) {
            subtitleAndControls
            categoryList
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            beginButton
                .background(.bar)
        }
        .navigationTitle(LocalizationKey.inspectionScopeTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(LocalizationKey.commonCancel.localized) { isDone = true }
            }
        }
        .onAppear {
            // Apply recommended defaults the first time the scope screen is shown.
            // Re-visiting after going back/forward preserves the user's edits.
            if viewModel.selectedCategoryKeys.isEmpty {
                viewModel.applyRecommendedCategoryDefaults()
            }
        }
    }

    // MARK: - Subtitle + bulk-edit controls

    private var subtitleAndControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizationKey.inspectionScopeSubtitle.localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(LocalizationKey.inspectionSelectAll.localized) {
                    viewModel.selectAllCategories()
                }
                .buttonStyle(.bordered)

                Button(LocalizationKey.inspectionClearAll.localized) {
                    viewModel.clearCategories()
                }
                .buttonStyle(.bordered)

                Button(LocalizationKey.inspectionRecommendedDefaults.localized) {
                    viewModel.applyRecommendedCategoryDefaults()
                }
                .buttonStyle(.bordered)
                .tint(Color.accentColor)
            }
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Category list

    private var categoryList: some View {
        List {
            if let template {
                ForEach(template.categories) { category in
                    CategoryToggleRow(
                        category: category,
                        isSelected: viewModel.isCategorySelected(category.titleKey),
                        onToggle: { viewModel.toggleCategory(category.titleKey) }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Begin button + summary

    private var beginButton: some View {
        VStack(spacing: 6) {
            Text(summaryText)
                .font(.caption)
                .foregroundStyle(viewModel.effectiveSelectedCount == 0 ? Color.orange : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                viewModel.createInspection(context: modelContext)
                isDone = true
            } label: {
                Text(LocalizationKey.inspectionStartWithScope.localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canBeginInspection)
        }
        .padding()
    }

    private var summaryText: String {
        if viewModel.effectiveSelectedCount == 0 {
            return LocalizationKey.inspectionNoScopeSelected.localized
        }
        return String(
            format: LocalizationKey.inspectionSelectedScopeSummary.localized,
            viewModel.effectiveSelectedCount,
            viewModel.generatedItemCount
        )
    }
}

// MARK: - CategoryToggleRow

private struct CategoryToggleRow: View {

    let category: ChecklistCategory
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.systemGray3))
                    .frame(width: 28)

                Text(L(category.titleKey))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text("\(category.items.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6), in: Capsule())
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
