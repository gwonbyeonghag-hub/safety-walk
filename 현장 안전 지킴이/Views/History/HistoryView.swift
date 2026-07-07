import SwiftUI
import SafetyWalkCore
import SwiftData

// Named HistoryTabView to match TASKS.md; file kept as HistoryView.swift for Xcode membership.
struct HistoryTabView: View {

    @Query(sort: \Inspection.startedAt, order: .reverse) private var inspections: [Inspection]
    @State private var selectedStatus: InspectionStatus? = nil
    @State private var viewModel = HomeViewModel()

    private var filteredInspections: [Inspection] {
        guard let status = selectedStatus else { return inspections }
        return inspections.filter { $0.status == status }
    }

    var body: some View {
        NavigationStack {
            if inspections.isEmpty {
                emptyState
                    .navigationTitle(LocalizationKey.historyTitle.localized)
            } else {
                VStack(spacing: 0) {
                    filterPicker
                    Divider()
                    if filteredInspections.isEmpty {
                        filteredEmptyState
                    } else {
                        List {
                            ForEach(filteredInspections) { inspection in
                                NavigationLink(value: inspection) {
                                    InspectionHistoryRowView(inspection: inspection,
                                                             viewModel: viewModel)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16,
                                                          bottom: 8, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle(LocalizationKey.historyTitle.localized)
                .navigationDestination(for: Inspection.self) { inspection in
                    InspectionDetailView(inspection: inspection)
                }
            }
        }
    }

    // MARK: - Filter

    private var filterPicker: some View {
        Picker("", selection: $selectedStatus) {
            Text(LocalizationKey.hazardFilterAll.localized)
                .tag(nil as InspectionStatus?)
            Text(LocalizationKey.inspectionStatusInProgress.localized)
                .tag(InspectionStatus.inProgress as InspectionStatus?)
            Text(LocalizationKey.inspectionStatusCompleted.localized)
                .tag(InspectionStatus.completed as InspectionStatus?)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 52))
                .foregroundStyle(Color(.systemGray3))
            Text(LocalizationKey.historyNoRecords.localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 44))
                .foregroundStyle(Color(.systemGray3))
            Text(LocalizationKey.historyNoFilterResults.localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}

// MARK: - InspectionHistoryRowView

private struct InspectionHistoryRowView: View {

    let inspection: Inspection
    let viewModel: HomeViewModel

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
                statusBadge
            }

            VStack(alignment: .leading, spacing: 2) {
                Label(viewModel.formattedDate(inspection.startedAt),
                      systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let completedAt = inspection.completedAt {
                    Label(viewModel.formattedDate(completedAt),
                          systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !(inspection.items ?? []).isEmpty {
                progressLine
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        let isCompleted = inspection.status == .completed
        return Text(viewModel.statusLabel(for: inspection))
            .font(.caption.weight(.medium))
            .foregroundStyle(isCompleted ? Color.green : Color.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(isCompleted ? Color.green.opacity(0.12) : Color.blue.opacity(0.12))
            }
    }

    private var progressLine: some View {
        let checked = (inspection.items ?? []).filter { $0.result != .unchecked }.count
        let total   = (inspection.items ?? []).count
        let failed  = (inspection.items ?? []).filter { $0.result == .fail }.count
        return HStack(spacing: 10) {
            Text(String(format: LocalizationKey.checklistProgress.localized, checked, total))
                .font(.caption)
                .foregroundStyle(.secondary)
            if failed > 0 {
                Text(String(format: LocalizationKey.checklistFailedCount.localized, failed))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }
        }
    }
}
