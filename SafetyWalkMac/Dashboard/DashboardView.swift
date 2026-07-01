import SwiftUI
import SwiftData
import SafetyWalkCore

/// Manager overview (WO-4 ②): per-site risk distribution (risk-chip language), open
/// corrective actions, risk-assessments due (annual), and recent inspections. Read-only,
/// calm-dense, macOS HIG, navy/cool accent.
struct DashboardView: View {
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query private var inspections: [Inspection]
    @Query private var hazards: [Hazard]
    @Query private var assessments: [RiskAssessment]

    private let columns = [GridItem(.adaptive(minimum: 340), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statRow
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    riskBySiteCard
                    openActionsCard
                    assessmentsDueCard
                    recentInspectionsCard
                }
            }
            .padding(20)
        }
        .navigationTitle(LocalizationKey.macDashboardTitle.localized)
        .background(.background)
    }

    // MARK: - Stat row

    private var statRow: some View {
        HStack(spacing: 12) {
            StatTile(value: sites.count, titleKey: .macStatSites, systemImage: "building.2")
            StatTile(value: completedInspections.count, titleKey: .macStatCompletedInspections, systemImage: "checklist")
            StatTile(value: openHazards.count, titleKey: .macStatOpenHazards, systemImage: "exclamationmark.triangle",
                     tint: openHazards.isEmpty ? nil : RiskLevel.high.uiColor)
            StatTile(value: dueAssessments.count, titleKey: .macStatAssessmentsDue, systemImage: "calendar.badge.clock",
                     tint: dueAssessments.isEmpty ? nil : RiskLevel.medium.uiColor)
        }
    }

    // MARK: - Cards

    private var riskBySiteCard: some View {
        MacCard(title: LocalizationKey.macRiskDistribution.localized, systemImage: "chart.bar") {
            if sites.isEmpty {
                EmptyLine()
            } else {
                VStack(spacing: 10) {
                    ForEach(sites) { site in
                        let dist = distribution(for: site)
                        HStack {
                            Text(site.name).font(.subheadline.weight(.medium))
                            Spacer()
                            RiskDistributionBar(distribution: dist)
                        }
                    }
                }
            }
        }
    }

    private var openActionsCard: some View {
        MacCard(title: LocalizationKey.macOpenCorrectiveActions.localized, systemImage: "wrench.and.screwdriver") {
            let items = openHazards.sorted { $0.riskLevel > $1.riskLevel }
            if items.isEmpty {
                EmptyLine(textKey: .macNoOpenItems)
            } else {
                VStack(spacing: 8) {
                    ForEach(items.prefix(6)) { h in
                        HStack(spacing: 10) {
                            RiskChip(level: h.riskLevel)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(h.hazardDescription).font(.callout).lineLimit(1)
                                Text("\(siteName(h.siteId)) · \(h.location)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(h.correctiveActionStatus.localizedLabel)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var assessmentsDueCard: some View {
        MacCard(title: LocalizationKey.macAssessmentsDue.localized, systemImage: "calendar.badge.exclamationmark") {
            let due = dueAssessments.sorted { $0.assessedAt < $1.assessedAt }
            if due.isEmpty {
                EmptyLine(textKey: .macNoOpenItems)
            } else {
                VStack(spacing: 8) {
                    ForEach(due.prefix(6)) { ra in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ra.siteName.isEmpty ? ra.method.localizedLabel : ra.siteName)
                                    .font(.callout).lineLimit(1)
                                Text(ra.method.localizedLabel)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            DueBadge(assessedAt: ra.assessedAt)
                        }
                    }
                }
            }
        }
    }

    private var recentInspectionsCard: some View {
        MacCard(title: LocalizationKey.macRecentInspections.localized, systemImage: "clock") {
            let recent = inspections.sorted { $0.startedAt > $1.startedAt }
            if recent.isEmpty {
                EmptyLine()
            } else {
                VStack(spacing: 8) {
                    ForEach(recent.prefix(6)) { insp in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(insp.siteName).font(.callout).lineLimit(1)
                                Text(insp.areaName ?? LocalizationKey.inspectionNoArea.localized)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(insp.startedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            StatusDot(status: insp.status)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Derived data

    private var completedInspections: [Inspection] { inspections.filter { $0.status == .completed } }
    private var openHazards: [Hazard] { hazards.filter { $0.correctiveActionStatus != .completed } }
    private var dueAssessments: [RiskAssessment] {
        assessments.filter { $0.kind == .regular && DueBadge.isDue($0.assessedAt) }
    }

    private func distribution(for site: Site) -> [RiskLevel: Int] {
        var d: [RiskLevel: Int] = [:]
        for h in hazards where h.siteId == site.id { d[h.riskLevel, default: 0] += 1 }
        return d
    }

    private func siteName(_ id: UUID) -> String {
        sites.first { $0.id == id }?.name ?? "—"
    }
}

// MARK: - Pieces

private struct StatTile: View {
    let value: Int
    let titleKey: LocalizationKey
    let systemImage: String
    var tint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint ?? Color.brandNavy)
            Text("\(value)")
                .font(.system(size: 30, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint ?? .primary)
            Text(titleKey.localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

/// Solid-dot counts per level — the risk-chip color language applied to a distribution.
private struct RiskDistributionBar: View {
    let distribution: [RiskLevel: Int]
    var body: some View {
        HStack(spacing: 12) {
            ForEach([RiskLevel.high, .medium, .low], id: \.self) { level in
                let count = distribution[level] ?? 0
                HStack(spacing: 4) {
                    RiskDot(level: level)
                    Text("\(count)").font(.callout).monospacedDigit()
                        .foregroundStyle(count == 0 ? .secondary : .primary)
                }
                .opacity(count == 0 ? 0.5 : 1)
            }
        }
    }
}

private struct DueBadge: View {
    let assessedAt: Date

    /// Regular assessments should be re-run at least annually; flag when the 1-year mark
    /// is within 30 days or already passed.
    static func isDue(_ assessedAt: Date) -> Bool {
        guard let deadline = Calendar.current.date(byAdding: .day, value: 365, to: assessedAt) else { return false }
        return Date() >= Calendar.current.date(byAdding: .day, value: -30, to: deadline)!
    }

    private var overdue: Bool {
        guard let deadline = Calendar.current.date(byAdding: .day, value: 365, to: assessedAt) else { return false }
        return Date() >= deadline
    }

    var body: some View {
        Text(overdue ? LocalizationKey.macOverdue.localized : LocalizationKey.macDueSoon.localized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((overdue ? RiskLevel.high.uiColor : RiskLevel.medium.uiColor), in: Capsule())
    }
}

private struct StatusDot: View {
    let status: InspectionStatus
    var body: some View {
        Circle()
            .fill(status == .completed ? Color.green : Color.brandNavy)
            .frame(width: 8, height: 8)
            .help(status == .completed
                  ? LocalizationKey.inspectionStatusCompleted.localized
                  : LocalizationKey.inspectionStatusInProgress.localized)
    }
}

private struct EmptyLine: View {
    var textKey: LocalizationKey = .macNoData
    var body: some View {
        Text(textKey.localized).font(.callout).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
