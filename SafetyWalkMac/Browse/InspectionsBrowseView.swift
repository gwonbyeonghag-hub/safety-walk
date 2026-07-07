import SwiftUI
import SwiftData
import SafetyWalkCore

struct InspectionsBrowseView: View {
    @Query private var inspections: [Inspection]

    private var sorted: [Inspection] { inspections.sorted { $0.startedAt > $1.startedAt } }

    var body: some View {
        BrowseLayout(items: sorted) { insp in
            VStack(alignment: .leading, spacing: 2) {
                Text(insp.siteName).font(.body).lineLimit(1)
                HStack(spacing: 6) {
                    Text(insp.areaName ?? LocalizationKey.inspectionNoArea.localized)
                    Text("·")
                    Text(insp.startedAt.formatted(date: .abbreviated, time: .omitted)).monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        } detail: { insp in
            detail(insp)
        }
        .navigationTitle(LocalizationKey.macSectionInspections.localized)
    }

    @ViewBuilder
    private func detail(_ insp: Inspection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailHeader(title: insp.siteName,
                         subtitle: insp.areaName ?? LocalizationKey.inspectionNoArea.localized)

            MacCard {
                VStack(spacing: 6) {
                    DetailField(label: LocalizationKey.summaryInspector.localized, value: insp.inspectorName)
                    DetailField(label: LocalizationKey.reportStatus.localized, value: statusLabel(insp.status))
                    DetailField(label: LocalizationKey.commonDone.localized,
                                value: insp.startedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            let groups = grouped(insp.items ?? [])
            ForEach(groups, id: \.category) { group in
                MacCard(title: L(group.category), systemImage: "checklist") {
                    VStack(spacing: 6) {
                        ForEach(group.items) { item in
                            HStack(spacing: 10) {
                                Text(L(item.title)).font(.callout)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ResultBadge(result: item.result)
                            }
                        }
                    }
                }
            }

            if !(insp.hazards ?? []).isEmpty {
                MacCard(title: LocalizationKey.reportHazardsAndActions.localized, systemImage: "exclamationmark.triangle") {
                    VStack(spacing: 8) {
                        ForEach((insp.hazards ?? []).sorted { $0.riskLevel > $1.riskLevel }) { h in
                            HStack(spacing: 10) {
                                RiskChip(level: h.riskLevel)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(h.hazardDescription).font(.callout).lineLimit(1)
                                    Text(h.location).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(h.correctiveActionStatus.localizedLabel)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func statusLabel(_ s: InspectionStatus) -> String {
        s == .completed ? LocalizationKey.inspectionStatusCompleted.localized
                        : LocalizationKey.inspectionStatusInProgress.localized
    }

    private func grouped(_ items: [ChecklistItem]) -> [(category: String, items: [ChecklistItem])] {
        var order: [String] = []
        var buckets: [String: [ChecklistItem]] = [:]
        for item in items.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            if buckets[item.category] == nil { order.append(item.category); buckets[item.category] = [] }
            buckets[item.category]?.append(item)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}

/// On-screen result badge (matches the report's pass=green / fail=red / n·a=gray).
struct ResultBadge: View {
    let result: ChecklistItemResult
    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color, in: Capsule())
    }
    private var label: String {
        switch result {
        case .pass: return LocalizationKey.checklistPass.localized
        case .fail: return LocalizationKey.checklistFail.localized
        case .notApplicable: return LocalizationKey.checklistNotApplicable.localized
        case .unchecked: return LocalizationKey.reportUnchecked.localized
        }
    }
    private var color: Color {
        switch result {
        case .pass: return .green
        case .fail: return .red
        case .notApplicable, .unchecked: return Color(white: 0.5)
        }
    }
}
