import SwiftUI
import SafetyWalkCore
import SwiftData

struct HomeView: View {

    @Query(sort: \Inspection.startedAt, order: .reverse)
    private var inspections: [Inspection]

    @Query
    private var hazards: [Hazard]

    @State private var viewModel = HomeViewModel()
    @State private var showStartInspection = false

    private var recentInspections: [Inspection] { Array(inspections.prefix(5)) }

    private var todayCount: Int {
        inspections.filter { Calendar.current.isDateInToday($0.startedAt) }.count
    }

    private var inProgressCount: Int {
        inspections.filter { $0.status == .inProgress }.count
    }

    // Open = corrective action not completed. The status rail summarises these
    // recorded hazards by risk level — it reports logged data, not a verdict.
    private var openHazards: [Hazard] {
        hazards.filter { $0.correctiveActionStatus != .completed }
    }
    private var openHazardCount: Int { openHazards.count }
    private func openCount(_ level: RiskLevel) -> Int {
        openHazards.filter { $0.riskLevel == level }.count
    }

    /// Accent reflects the highest open risk level; green when nothing is open.
    private var railAccent: Color {
        if openCount(.high) > 0 { return .red }
        if openCount(.medium) > 0 { return .orange }
        if openCount(.low) > 0 { return .riskLow }
        return .green
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusRail
                    inspectionSummary
                    startInspectionButton
                    riskAssessmentEntry
                    recentInspectionsSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle(LocalizationKey.tabHome.localized)
            .navigationDestination(for: Inspection.self) { inspection in
                InspectionDetailView(inspection: inspection)
            }
        }
    }

    // MARK: - Status rail (signature element)

    private var statusRail: some View {
        let total = openHazardCount
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: total == 0 ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(railAccent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(total == 0
                         ? LocalizationKey.homeAllClear.localized
                         : LocalizationKey.homeOpenHazards.localized)
                        .font(.headline)
                    if total == 0 {
                        Text(LocalizationKey.homeNoOpenHazards.localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                if total > 0 {
                    Text("\(total)")
                        .font(.title.bold())
                        .monospacedDigit()
                        .foregroundStyle(railAccent)
                }
            }
            .padding(16)

            if total > 0 {
                Divider()
                HStack(spacing: 0) {
                    riskSegment(.high)
                    segmentDivider
                    riskSegment(.medium)
                    segmentDivider
                    riskSegment(.low)
                }
                .padding(.vertical, 10)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(railAccent.opacity(0.10))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(railAccent.opacity(0.22), lineWidth: 1)
        )
    }

    private var segmentDivider: some View {
        Divider().frame(height: 26)
    }

    // A single segment of the rail — colour + label + count, no nested card.
    private func riskSegment(_ level: RiskLevel) -> some View {
        let count = openCount(level)
        return VStack(spacing: 4) {
            HStack(spacing: 5) {
                RiskDot(level: level, size: 9)
                Text(level.localizedLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(count)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(level.localizedLabel) \(count)")
    }

    // MARK: - Inspection summary (compact, one surface)

    private var inspectionSummary: some View {
        HStack(spacing: 0) {
            summaryStat(
                systemImage: "checklist",
                value: todayCount,
                label: LocalizationKey.homeInspectionsToday.localized
            )
            segmentDivider
            summaryStat(
                systemImage: "clock.arrow.circlepath",
                value: inProgressCount,
                label: LocalizationKey.inspectionStatusInProgress.localized,
                valueColor: inProgressCount > 0 ? .blue : .primary
            )
        }
        .padding(.vertical, 14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func summaryStat(systemImage: String,
                             value: Int,
                             label: String,
                             valueColor: Color = .primary) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: - Primary action

    private var startInspectionButton: some View {
        Button {
            showStartInspection = true
        } label: {
            Label(LocalizationKey.homeStartInspection.localized, systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .sheet(isPresented: $showStartInspection) {
            StartInspectionFlow()
        }
    }

    // MARK: - Risk assessment entry (≤2 taps from Home → list → create/detail)

    private var riskAssessmentEntry: some View {
        NavigationLink {
            RiskAssessmentListView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "list.clipboard.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizationKey.raTitle.localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(LocalizationKey.raHomeCardSubtitle.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ra_home_card")
    }

    // MARK: - Recent inspections

    private var recentInspectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationKey.homeRecentInspections.localized)
                .font(.headline)

            if recentInspections.isEmpty {
                emptyState
            } else {
                ForEach(recentInspections) { inspection in
                    NavigationLink(value: inspection) {
                        InspectionRowView(inspection: inspection, viewModel: viewModel)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text(LocalizationKey.homeNoInspectionsYet.localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

}

// MARK: - InspectionRowView

private struct InspectionRowView: View {
    let inspection: Inspection
    let viewModel: HomeViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(inspection.siteName)
                    .font(.subheadline.weight(.semibold))

                if let area = inspection.areaName, !area.isEmpty {
                    Text(area)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(viewModel.formattedDate(inspection.startedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !(inspection.items ?? []).isEmpty {
                    HStack(spacing: 10) {
                        Label("\(viewModel.passCount(for: inspection))",
                              systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Label("\(viewModel.failCount(for: inspection))",
                              systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            Text(viewModel.statusLabel(for: inspection))
                .font(.caption.weight(.medium))
                .foregroundStyle(viewModel.statusColor(for: inspection))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    viewModel.statusColor(for: inspection).opacity(0.12),
                    in: Capsule()
                )
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .modelContainer(
            for: [Site.self, Area.self, Inspection.self, ChecklistItem.self, Hazard.self],
            inMemory: true
        )
}
