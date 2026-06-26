import SwiftUI
import SwiftData

struct InspectionView: View {

    @Query(sort: \Inspection.startedAt, order: .reverse) private var inspections: [Inspection]
    @State private var showStartInspection = false
    @State private var viewModel = HomeViewModel()

    private var activeInspections: [Inspection] {
        inspections.filter { $0.status == .inProgress }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeInspections.isEmpty {
                    emptyState
                        .safeAreaInset(edge: .bottom, spacing: 0) { startInspectionButton }
                } else {
                    List {
                        ForEach(activeInspections) { inspection in
                            NavigationLink(value: inspection) {
                                ActiveInspectionRowView(inspection: inspection,
                                                        viewModel: viewModel)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16,
                                                      bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .safeAreaInset(edge: .bottom, spacing: 0) { startInspectionButton }
                }
            }
            .navigationTitle(LocalizationKey.tabInspection.localized)
            .navigationDestination(for: Inspection.self) { inspection in
                InspectionDetailView(inspection: inspection)
            }
        }
        .sheet(isPresented: $showStartInspection) {
            StartInspectionFlow()
        }
    }

    // MARK: - Start Inspection button

    private var startInspectionButton: some View {
        Button {
            showStartInspection = true
        } label: {
            Text(LocalizationKey.homeStartInspection.localized)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .padding()
        .background(.bar)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 52))
                .foregroundStyle(Color(.systemGray3))
            Text(LocalizationKey.inspectionNoActiveInspections.localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}

// MARK: - ActiveInspectionRowView

private struct ActiveInspectionRowView: View {

    let inspection: Inspection
    let viewModel: HomeViewModel

    private var checkedCount: Int { inspection.items.filter { $0.result != .unchecked }.count }
    private var failedCount: Int  { inspection.items.filter { $0.result == .fail }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(inspection.siteName)
                        .font(.subheadline.weight(.semibold))
                    if let area = inspection.areaName, !area.isEmpty {
                        Text(area)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(LocalizationKey.inspectionStatusInProgress.localized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        Capsule().fill(Color.orange.opacity(0.12))
                    }
            }

            Label(viewModel.formattedDate(inspection.startedAt),
                  systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !inspection.items.isEmpty {
                HStack(spacing: 10) {
                    Text(String(format: LocalizationKey.checklistProgress.localized,
                                checkedCount, inspection.items.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if failedCount > 0 {
                        Text(String(format: LocalizationKey.checklistFailedCount.localized,
                                    failedCount))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
