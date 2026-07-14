import SwiftUI
import SwiftData
import SafetyWalkCore

/// Manager overview (WO-4 ②, WO-8 polish): per-site risk distribution (risk-chip
/// language), open corrective actions, risk-assessments due (annual), and recent
/// inspections. Read-only, calm-dense, macOS HIG, cool-neutral surfaces + navy accent
/// (mockup: docs/design/macos-dashboard-mockup.html). Data/logic unchanged from WO-4.
struct DashboardView: View {
    /// Lets a card ("전체 N개 현장 보기") jump the shell to another sidebar section.
    var onSelectSection: (MacSection) -> Void = { _ in }

    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query private var inspections: [Inspection]
    @Query private var hazards: [Hazard]
    @Query private var assessments: [RiskAssessment]

    private let columns = [GridItem(.adaptive(minimum: 340), spacing: MacTheme.s4)]

    /// WO-11: all 4 cards show the same top-N and settle to the same fixed height
    /// regardless of how much data each has, so the grid stays even instead of
    /// jagged. Short lists top-align and leave blank space above the footer;
    /// the "전체 보기" footer is always visible (not conditional on overflow).
    private let cardRowLimit = 5
    private let cardBodyHeight: CGFloat = 300

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacTheme.s5) {
                header
                statRow
                LazyVGrid(columns: columns, alignment: .leading, spacing: MacTheme.s4) {
                    riskBySiteCard
                    openActionsCard
                    assessmentsDueCard
                    recentInspectionsCard
                }
            }
            .padding(MacTheme.s6)
        }
        .navigationTitle(LocalizationKey.macDashboardTitle.localized)
        .background(Color.macBg)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizationKey.macDashboardTitle.localized)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color.macInk)
            Text(String(format: LocalizationKey.macDashboardSubtitle.localized, sites.count))
                .font(.system(size: 13))
                .foregroundStyle(Color.macMuted)
        }
    }

    // MARK: - Stat row

    private var statRow: some View {
        HStack(spacing: MacTheme.s4) {
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
            cardBody(footerLabel: String(format: LocalizationKey.macViewAllSites.localized, sites.count), section: .sites) {
                if sites.isEmpty {
                    EmptyLine()
                } else {
                    // Most-severe first (open 높음 desc → 보통 desc), top N — consistent with
                    // the other cards. The full list lives in the 현장 (Sites) section.
                    MacCardRows(data: Array(sitesBySeverity.prefix(cardRowLimit))) { site in
                        HStack {
                            Text(site.name)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(Color.macInk)
                            Spacer()
                            RiskDistributionBar(distribution: distribution(for: site))
                        }
                    }
                }
            }
        }
    }

    private var openActionsCard: some View {
        MacCard(title: LocalizationKey.macOpenCorrectiveActions.localized, systemImage: "wrench.and.screwdriver") {
            cardBody(footerLabel: LocalizationKey.macViewAllHazards.localized, section: .hazards) {
                let items = Array(openHazards.sorted { $0.riskLevel > $1.riskLevel }.prefix(cardRowLimit))
                if items.isEmpty {
                    EmptyLine(textKey: .macNoOpenItems)
                } else {
                    MacCardRows(data: items) { h in
                        HStack(spacing: MacTheme.s3) {
                            RiskChip(level: h.riskLevel)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h.hazardDescription)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(Color.macInk)
                                    .lineLimit(1)
                                Text("\(siteName(h.siteId)) · \(h.location)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.macMuted)
                            }
                            Spacer(minLength: MacTheme.s2)
                            Text(h.correctiveActionStatus.localizedLabel)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.macMuted)
                        }
                    }
                }
            }
        }
    }

    private var assessmentsDueCard: some View {
        MacCard(title: LocalizationKey.macAssessmentsDue.localized, systemImage: "calendar.badge.exclamationmark") {
            cardBody(footerLabel: LocalizationKey.macViewAllAssessments.localized, section: .riskAssessments) {
                let due = Array(dueAssessments.sorted { ($0.assessedAt ?? .distantPast) < ($1.assessedAt ?? .distantPast) }.prefix(cardRowLimit))
                if due.isEmpty {
                    EmptyLine(textKey: .macNoOpenItems)
                } else {
                    MacCardRows(data: due) { ra in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ra.siteName.isEmpty ? ra.method.localizedLabel : ra.siteName)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(Color.macInk)
                                    .lineLimit(1)
                                Text(ra.method.localizedLabel)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.macMuted)
                            }
                            Spacer(minLength: MacTheme.s2)
                            if let at = ra.assessedAt { DueBadge(assessedAt: at) }
                        }
                    }
                }
            }
        }
    }

    private var recentInspectionsCard: some View {
        MacCard(title: LocalizationKey.macRecentInspections.localized, systemImage: "clock") {
            cardBody(footerLabel: LocalizationKey.macViewAllInspections.localized, section: .inspections) {
                let recent = Array(inspections.sorted { $0.startedAt > $1.startedAt }.prefix(cardRowLimit))
                if recent.isEmpty {
                    EmptyLine()
                } else {
                    MacCardRows(data: recent) { insp in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(insp.siteName)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(Color.macInk)
                                    .lineLimit(1)
                                Text(insp.areaName ?? LocalizationKey.inspectionNoArea.localized)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.macMuted)
                            }
                            Spacer(minLength: MacTheme.s2)
                            Text(insp.startedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 12.5))
                                .monospacedDigit()
                                .foregroundStyle(Color.macInk2)
                            StatusDot(status: insp.status)
                        }
                    }
                }
            }
        }
    }

    /// WO-11: rows top-aligned, footer pinned to the bottom of a fixed-height box —
    /// so a short list leaves blank space above the footer instead of shrinking the
    /// card, and the "전체 보기" footer is always visible.
    private func cardBody<Rows: View>(
        footerLabel: String,
        section: MacSection,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            rows()
            Spacer(minLength: 0)
            Rectangle().fill(Color.macBorder).frame(height: 1)
            Button {
                onSelectSection(section)
            } label: {
                HStack(spacing: 5) {
                    Text(footerLabel)
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.macAccent)
                .padding(.top, MacTheme.s2 + 2)
            }
            .buttonStyle(.plain)
        }
        .frame(height: cardBodyHeight, alignment: .top)
    }

    // MARK: - Derived data (unchanged from WO-4)

    private var completedInspections: [Inspection] { inspections.filter { $0.status == .completed } }
    private var openHazards: [Hazard] { hazards.filter { $0.correctiveActionStatus != .completed } }
    private var dueAssessments: [RiskAssessment] {
        assessments.filter {
            guard $0.kind == .regular, let at = $0.assessedAt else { return false }
            return RiskAssessment.dueStatus(assessedAt: at) != .notDue
        }
    }

    private func distribution(for site: Site) -> [RiskLevel: Int] {
        var d: [RiskLevel: Int] = [:]
        for h in hazards where h.siteId == site.id { d[h.riskLevel, default: 0] += 1 }
        return d
    }

    /// Open (미조치) hazard counts per level for a site — drives the severity ordering.
    private func openDistribution(for site: Site) -> [RiskLevel: Int] {
        var d: [RiskLevel: Int] = [:]
        for h in openHazards where h.siteId == site.id { d[h.riskLevel, default: 0] += 1 }
        return d
    }

    /// Sites ordered by open severity: 높음 desc → 보통 desc → 낮음 desc, then name for a
    /// stable order. View-only ordering; the underlying data is unchanged.
    private var sitesBySeverity: [Site] {
        sites.sorted { a, b in
            let da = openDistribution(for: a), db = openDistribution(for: b)
            for level in [RiskLevel.high, .medium, .low] {
                let ca = da[level] ?? 0, cb = db[level] ?? 0
                if ca != cb { return ca > cb }
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func siteName(_ id: UUID) -> String {
        sites.first { $0.id == id }?.name ?? "—"
    }
}

// MARK: - Pieces

/// Mockup `.stat`: icon in a soft rounded tile, big tabular number, muted label.
private struct StatTile: View {
    let value: Int
    let titleKey: LocalizationKey
    let systemImage: String
    var tint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: MacTheme.smallRadius)
                    .fill(tint.map { $0.opacity(0.14) } ?? Color.macAccentSoft)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint ?? Color.macAccent)
            }
            .frame(width: 30, height: 30)
            .padding(.bottom, MacTheme.s3)

            Text("\(value)")
                .font(.system(size: 29, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint ?? Color.macInk)

            Text(titleKey.localized)
                .font(.system(size: 12))
                .foregroundStyle(Color.macMuted)
                .padding(.top, 6)
        }
        .padding(MacTheme.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macCardSurface()
    }
}

/// Solid-dot counts per level — the risk-chip color language (signature) applied to a
/// distribution. Zero counts read faint (mockup `.cnt.z`).
private struct RiskDistributionBar: View {
    let distribution: [RiskLevel: Int]
    var body: some View {
        HStack(spacing: MacTheme.s3) {
            ForEach([RiskLevel.high, .medium, .low], id: \.self) { level in
                let count = distribution[level] ?? 0
                HStack(spacing: 6) {
                    RiskDot(level: level, size: 9)
                        .opacity(count == 0 ? 0.35 : 1)
                    Text("\(count)")
                        .font(.system(size: 13, weight: count == 0 ? .medium : .semibold))
                        .monospacedDigit()
                        .foregroundStyle(count == 0 ? Color.macFaint : Color.macInk)
                }
                .frame(minWidth: 34, alignment: .leading)
            }
        }
    }
}

/// Assessment-due pill — signature risk color as a soft-tinted pill (mockup `.pill.over`).
private struct DueBadge: View {
    let assessedAt: Date

    // Deadline urgency comes from the single shared rule (SafetyWalkCore
    // RiskAssessment.dueStatus, 365d + 30d grace) — no macOS-local copy. Parity is
    // covered by AssessmentDueTests.matchesMacDueBadgeRule (0–420 day sweep).
    private var overdue: Bool {
        RiskAssessment.dueStatus(assessedAt: assessedAt) == .overdue
    }

    var body: some View {
        let color = overdue ? RiskLevel.high.uiColor : RiskLevel.medium.uiColor
        Text(overdue ? LocalizationKey.macOverdue.localized : LocalizationKey.macDueSoon.localized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.13), in: Capsule())
    }
}

private struct StatusDot: View {
    let status: InspectionStatus
    var body: some View {
        Circle()
            .fill(status == .completed ? Color.macOk : Color.macAccent)
            .frame(width: 8, height: 8)
            .help(status == .completed
                  ? LocalizationKey.inspectionStatusCompleted.localized
                  : LocalizationKey.inspectionStatusInProgress.localized)
    }
}

private struct EmptyLine: View {
    var textKey: LocalizationKey = .macNoData
    var body: some View {
        Text(textKey.localized)
            .font(.system(size: 13))
            .foregroundStyle(Color.macMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }
}
