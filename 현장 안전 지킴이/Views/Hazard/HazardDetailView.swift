import SwiftUI
import SwiftData

struct HazardDetailView: View {

    @Bindable var hazard: Hazard
    @Environment(\.modelContext) private var modelContext

    @State private var photo: UIImage?

    var body: some View {
        List {
            photoSection
            infoSection
            descriptionSection
            statusSection
            timestampSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(LocalizationKey.hazardDetailTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadPhoto() }
    }

    // MARK: - Sections

    @ViewBuilder private var photoSection: some View {
        if let img = photo {
            Section {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }
        }
    }

    private var infoSection: some View {
        Section {
            LabeledContent(LocalizationKey.hazardLocation.localized,
                           value: hazard.location)
            LabeledContent(LocalizationKey.hazardType.localized,
                           value: typeLabel(hazard.type))
            LabeledContent(LocalizationKey.hazardRiskLevel.localized) {
                Text(riskLabelString(hazard.riskLevel))
                    .foregroundStyle(riskColor(hazard.riskLevel))
                    .fontWeight(.semibold)
            }
        }
    }

    private var descriptionSection: some View {
        Section(LocalizationKey.hazardDescription.localized) {
            Text(hazard.hazardDescription)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusSection: some View {
        Section(LocalizationKey.hazardCorrectiveStatus.localized) {
            Picker(LocalizationKey.hazardCorrectiveStatus.localized,
                   selection: $hazard.correctiveActionStatus) {
                ForEach(CorrectiveActionStatus.allCases, id: \.self) { status in
                    Text(statusLabel(status)).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: hazard.correctiveActionStatus) { _, _ in
                hazard.updatedAt = Date()
                try? modelContext.save()
            }
        }
    }

    private var timestampSection: some View {
        Section {
            LabeledContent(
                LocalizationKey.hazardCreatedAt.localized,
                value: hazard.createdAt.formatted(date: .abbreviated, time: .shortened)
            )
            LabeledContent(
                LocalizationKey.hazardUpdatedAt.localized,
                value: hazard.updatedAt.formatted(date: .abbreviated, time: .shortened)
            )
        }
    }

    // MARK: - Photo

    private func loadPhoto() {
        guard photo == nil, !hazard.photoPath.isEmpty else { return }
        photo = PhotoStorageService().load(relativePath: hazard.photoPath)
    }

    // MARK: - Label helpers

    private func typeLabel(_ type: HazardType) -> String {
        switch type {
        case .fallRisk:   return LocalizationKey.hazardTypeFallRisk.localized
        case .electrical: return LocalizationKey.hazardTypeElectrical.localized
        case .fire:       return LocalizationKey.hazardTypeFire.localized
        case .chemical:   return LocalizationKey.hazardTypeChemical.localized
        case .general:    return LocalizationKey.hazardTypeGeneral.localized
        case .other:      return LocalizationKey.hazardTypeOther.localized
        }
    }

    private func riskLabelString(_ level: RiskLevel) -> String {
        switch level {
        case .low:    return LocalizationKey.riskLow.localized
        case .medium: return LocalizationKey.riskMedium.localized
        case .high:   return LocalizationKey.riskHigh.localized
        }
    }

    private func riskColor(_ level: RiskLevel) -> Color {
        switch level {
        case .low:    return .riskLow
        case .medium: return .orange
        case .high:   return .red
        }
    }

    private func statusLabel(_ status: CorrectiveActionStatus) -> String {
        switch status {
        case .notStarted: return LocalizationKey.statusNotStarted.localized
        case .inProgress: return LocalizationKey.statusInProgress.localized
        case .completed:  return LocalizationKey.statusCompleted.localized
        }
    }
}
