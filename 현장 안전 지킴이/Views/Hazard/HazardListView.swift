import SwiftUI
import SwiftData

// Named HazardsTabView to match TASKS.md; file kept as HazardListView.swift for Xcode membership.
struct HazardsTabView: View {

    @Query(sort: \Hazard.createdAt, order: .reverse) private var hazards: [Hazard]
    // Sites offered when registering a standalone hazard (PRD F-04 / F-01).
    // Owned here at the tab root and passed into the sheet (shared sheet has no @Query).
    @Query(sort: \Site.name) private var sites: [Site]

    @State private var selectedRisk: RiskLevel?                = nil
    @State private var selectedStatus: CorrectiveActionStatus? = nil
    @State private var showAddHazard = false

    private var filteredHazards: [Hazard] {
        hazards.filter { hazard in
            let riskMatch   = selectedRisk   == nil || hazard.riskLevel              == selectedRisk
            let statusMatch = selectedStatus == nil || hazard.correctiveActionStatus == selectedStatus
            return riskMatch && statusMatch
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if hazards.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        filterBar
                        Divider()
                        if filteredHazards.isEmpty {
                            filteredEmptyState
                        } else {
                            List {
                                ForEach(filteredHazards) { hazard in
                                    NavigationLink {
                                        HazardDetailView(hazard: hazard)
                                    } label: {
                                        HazardRowView(hazard: hazard)
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(LocalizationKey.tabHazards.localized)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddHazard = true
                    } label: {
                        Label(LocalizationKey.homeAddHazard.localized, systemImage: "plus")
                    }
                }
            }
            // Sheet hosted on the tab-root NavigationStack (the safe place per
            // /navigation-qa). Standalone registration: no inspection, pick a site.
            .sheet(isPresented: $showAddHazard) {
                HazardRegistrationView(availableSites: sites)
            }
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                riskFilterMenu
                statusFilterMenu
                if selectedRisk != nil || selectedStatus != nil {
                    Button {
                        selectedRisk   = nil
                        selectedStatus = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondary)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(LocalizationKey.hazardClearFilters.localized)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
    }

    private var riskFilterMenu: some View {
        Menu {
            Button(LocalizationKey.hazardFilterAll.localized) { selectedRisk = nil }
            Divider()
            ForEach(RiskLevel.allCases, id: \.self) { level in
                Button(riskLabel(level)) { selectedRisk = level }
            }
        } label: {
            filterChip(
                title:       selectedRisk.map { riskLabel($0) } ?? LocalizationKey.hazardRiskLevel.localized,
                isActive:    selectedRisk != nil,
                activeColor: selectedRisk.map { riskColor($0) } ?? Color(.systemGray5)
            )
        }
        .buttonStyle(.plain)
    }

    private var statusFilterMenu: some View {
        Menu {
            Button(LocalizationKey.hazardFilterAll.localized) { selectedStatus = nil }
            Divider()
            ForEach(CorrectiveActionStatus.allCases, id: \.self) { status in
                Button(statusLabel(status)) { selectedStatus = status }
            }
        } label: {
            filterChip(
                title:       selectedStatus.map { statusLabel($0) } ?? LocalizationKey.hazardCorrectiveStatus.localized,
                isActive:    selectedStatus != nil,
                activeColor: selectedStatus.map { statusColor($0) } ?? Color(.systemGray5)
            )
        }
        .buttonStyle(.plain)
    }

    private func filterChip(title: String, isActive: Bool, activeColor: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline.weight(isActive ? .semibold : .regular))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .background {
            Capsule().fill(isActive ? activeColor : Color(.systemGray6))
        }
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 52))
                .foregroundStyle(Color(.systemGray3))
            Text(LocalizationKey.hazardNoHazardsYet.localized)
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
            Text(LocalizationKey.hazardNoFilterResults.localized)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Label helpers

    fileprivate func riskLabel(_ level: RiskLevel) -> String {
        switch level {
        case .low:    return LocalizationKey.riskLow.localized
        case .medium: return LocalizationKey.riskMedium.localized
        case .high:   return LocalizationKey.riskHigh.localized
        }
    }

    fileprivate func riskColor(_ level: RiskLevel) -> Color {
        switch level {
        case .low:    return .riskLow
        case .medium: return .orange
        case .high:   return .red
        }
    }

    fileprivate func statusLabel(_ status: CorrectiveActionStatus) -> String {
        switch status {
        case .notStarted: return LocalizationKey.statusNotStarted.localized
        case .inProgress: return LocalizationKey.statusInProgress.localized
        case .completed:  return LocalizationKey.statusCompleted.localized
        }
    }

    private func statusColor(_ status: CorrectiveActionStatus) -> Color {
        switch status {
        case .notStarted: return Color(.systemGray)
        case .inProgress: return Color.blue
        case .completed:  return Color.green
        }
    }
}

// MARK: - HazardRowView

private struct HazardRowView: View {

    let hazard: Hazard
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailView
            VStack(alignment: .leading, spacing: 4) {
                Text(hazard.hazardDescription)
                    .font(.body)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(hazard.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    riskBadge
                    statusBadge
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear { loadThumbnail() }
    }

    @ViewBuilder private var thumbnailView: some View {
        if let thumb = thumbnail {
            Image(uiImage: thumb)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color(.systemGray3))
                }
        }
    }

    private var riskBadge: some View {
        Text(riskLabel(hazard.riskLevel))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(riskColor(hazard.riskLevel))
            .background {
                Capsule().fill(riskColor(hazard.riskLevel).opacity(0.12))
            }
    }

    private var statusBadge: some View {
        Text(statusLabel(hazard.correctiveActionStatus))
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(Color(.systemGray))
            .background {
                Capsule().fill(Color(.systemGray5))
            }
    }

    private func loadThumbnail() {
        guard thumbnail == nil, !hazard.photoPath.isEmpty else { return }
        thumbnail = PhotoStorageService().load(relativePath: hazard.photoPath)
    }

    private func riskLabel(_ level: RiskLevel) -> String {
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
