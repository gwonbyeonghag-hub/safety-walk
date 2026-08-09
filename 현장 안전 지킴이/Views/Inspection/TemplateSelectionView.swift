import SwiftUI
import SafetyWalkCore
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

    // WO LEGAL-3B §E: US Federal 템플릿 선택 화면 — 시작(다음 단계로 진행) 전에 경고를 볼 수 있도록
    // 해당 템플릿 행에 표시한다. KR 행에는 나타나지 않는다.
    private var showsFederalNotice: Bool {
        ChecklistTemplatePolicy.showsFederalNotice(forTemplateId: template.id)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.localizedDisplayName)
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

                    if showsFederalNotice {
                        USFederalNoticeInline()
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

// MARK: - Template display name (WO LEGAL-3B §C)

private extension ChecklistTemplate {
    /// The new US Federal templates show a localized display name; everything else (Korea,
    /// the retired legacy global template) falls back to the JSON's literal `name` field —
    /// "기존 literal name은 레거시 fallback으로 유지".
    var localizedDisplayName: String {
        switch id {
        case "us-federal-general-industry-v1": return LocalizationKey.inspectionTemplateUSGeneralName.localized
        case "us-federal-construction-v1":     return LocalizationKey.inspectionTemplateUSConstructionName.localized
        default:                               return name
        }
    }
}
