import SwiftUI
import SwiftData

struct TemplateSelectionView: View {

    @Binding var isDone: Bool
    @Binding var path: [FlowStep]
    @Environment(StartInspectionViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(viewModel.templates) { template in
                    TemplateRowView(
                        template: template,
                        isSelected: viewModel.selectedTemplate?.id == template.id
                    ) {
                        viewModel.selectedTemplate = template
                    }
                }
            }
            .listStyle(.insetGrouped)

            nextButton
        }
        .navigationTitle(LocalizationKey.inspectionSelectTemplate.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(LocalizationKey.commonCancel.localized) { isDone = true }
            }
        }
        .onAppear {
            if viewModel.templates.isEmpty {
                viewModel.loadTemplates()
            }
        }
    }

    // MARK: - Subviews

    private var nextButton: some View {
        Button {
            path.append(.scope)
        } label: {
            Text(LocalizationKey.commonNext.localized)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canProceedFromTemplate)
        .padding()
    }
}

// MARK: - TemplateRowView

private struct TemplateRowView: View {
    let template: ChecklistTemplate
    let isSelected: Bool
    let onTap: () -> Void

    private var totalItems: Int {
        template.categories.reduce(0) { $0 + $1.items.count }
    }

    private var regionLabel: String {
        switch template.regionProfile {
        case .korea:  return LocalizationKey.settingsRegionKorea.localized
        case .global: return LocalizationKey.settingsRegionGlobal.localized
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(regionLabel)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint, in: Capsule())

                        Text(String(format: LocalizationKey.inspectionTemplateSummary.localized,
                                    template.categories.count, totalItems))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .font(.title3)
                        .padding(.top, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}
