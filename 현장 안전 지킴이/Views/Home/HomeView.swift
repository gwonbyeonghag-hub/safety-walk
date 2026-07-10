import SwiftUI
import SafetyWalkCore
import SwiftData

struct HomeView: View {

    @Query(sort: \Inspection.startedAt, order: .reverse)
    private var inspections: [Inspection]

    @Query
    private var hazards: [Hazard]

    // Additive queries used only by the iPad (regular) two-column layout. On iPhone
    // (compact) the layout below never renders these, so the phone home is unchanged.
    @Query(sort: \Site.name) private var sites: [Site]
    @Query private var assessments: [RiskAssessment]

    @Environment(\.horizontalSizeClass) private var hSize

    @State private var viewModel = HomeViewModel()
    @State private var showStartInspection = false
    @State private var showAddHazard = false

    private var recentInspections: [Inspection] { Array(inspections.prefix(5)) }

    /// 정기 assessments at/near their annual deadline — shared rule (SafetyWalkCore).
    private var dueAssessments: [RiskAssessment] {
        assessments
            .filter { $0.kind == .regular && RiskAssessment.dueStatus(assessedAt: $0.assessedAt) != .notDue }
            .sorted { $0.assessedAt < $1.assessedAt }
    }

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
                Group {
                    if hSize == .regular {
                        regularBody      // iPad: two columns (WO-7 mockup)
                    } else {
                        compactBody      // iPhone: unchanged single column
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle(LocalizationKey.tabHome.localized)
            .navigationDestination(for: Inspection.self) { inspection in
                InspectionDetailView(inspection: inspection)
            }
            .sheet(isPresented: $showStartInspection) {
                StartInspectionFlow()
            }
            .sheet(isPresented: $showAddHazard) {
                HazardRegistrationView(availableSites: sites)
            }
        }
    }

    // MARK: - Layouts

    /// iPhone (compact) — the original single-column field-tool home. Unchanged.
    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            statusRail
            inspectionSummary
            startInspectionButton
            riskAssessmentEntry
            recentInspectionsSection
        }
    }

    /// iPad (regular) — the same home content spread across two columns: left = open-hazard
    /// rail + quick actions, right = recent inspections + assessments due (WO-7 mockup).
    private var regularBody: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 20) {
                statusRail
                quickActionsCard
            }
            .frame(maxWidth: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 20) {
                recentInspectionsSection
                assessmentsDueCard
            }
            .frame(maxWidth: .infinity, alignment: .top)
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
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: AppSurface.cornerRadius))
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
        // Sheet moved to body level (WO-7) so the iPad quick-actions card can trigger the
        // same flow; presentation is identical to before on iPhone.
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
            .cardSurface()
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

    // MARK: - iPad (regular) cards

    /// Quick actions (WO-7 mockup): 점검 시작 (primary) + 위험요인 추가 (secondary). Both reuse
    /// existing flows (StartInspectionFlow / HazardRegistrationView) — no new behavior.
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationKey.homeQuickActions.localized)
                .font(.headline)
            Button {
                showStartInspection = true
            } label: {
                Label(LocalizationKey.homeStartInspection.localized, systemImage: "checklist")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            Button {
                showAddHazard = true
            } label: {
                Label(LocalizationKey.homeAddHazard.localized, systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .cardSurface()
    }

    /// Assessments due (WO-7 mockup): 정기 assessments at/near their annual deadline, using
    /// the shared `RiskAssessment.dueStatus` rule. Read-only; taps route to the RA list.
    private var assessmentsDueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationKey.homeAssessmentsDue.localized)
                .font(.headline)

            if dueAssessments.isEmpty {
                Text(LocalizationKey.homeNoDueAssessments.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(dueAssessments.prefix(4)) { ra in
                    NavigationLink {
                        RiskAssessmentListView()
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ra.siteName.isEmpty ? ra.method.localizedLabel : ra.siteName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(ra.kind.localizedLabel) · \(ra.method.localizedLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            DuePill(status: RiskAssessment.dueStatus(assessedAt: ra.assessedAt))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .cardSurface()
    }

}

// MARK: - DuePill

/// Soft-tinted deadline pill for the assessments-due card. Colors are the risk-semantic
/// ramp (overdue = high, due-soon = medium) — urgency, not decoration (DESIGN_DIRECTION).
private struct DuePill: View {
    let status: AssessmentDueStatus
    var body: some View {
        let overdue = status == .overdue
        let color: Color = overdue ? .red : .orange
        Text(overdue ? LocalizationKey.homeOverdue.localized : LocalizationKey.homeDueSoon.localized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(color.opacity(0.13), in: Capsule())
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
        .cardSurface()
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
