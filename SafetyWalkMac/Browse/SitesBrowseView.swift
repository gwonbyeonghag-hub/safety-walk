import SwiftUI
import SwiftData
import SafetyWalkCore

struct SitesBrowseView: View {
    @Query(sort: \Site.createdAt) private var sites: [Site]
    @Query private var hazards: [Hazard]
    @Query private var inspections: [Inspection]

    var body: some View {
        BrowseLayout(items: sites) { site in
            VStack(alignment: .leading, spacing: 2) {
                Text(site.name).font(.body)
                Text(site.address ?? "—").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        } detail: { site in
            detail(site)
        }
        .navigationTitle(LocalizationKey.macSectionSites.localized)
    }

    @ViewBuilder
    private func detail(_ site: Site) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailHeader(title: site.name, subtitle: site.address)

            MacCard(title: LocalizationKey.macAreas.localized, systemImage: "map") {
                if (site.areas ?? []).isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    FlowRow((site.areas ?? []).map(\.name))
                }
            }

            MacCard(title: LocalizationKey.macSectionHazards.localized, systemImage: "exclamationmark.triangle") {
                let siteHazards = hazards.filter { $0.siteId == site.id }
                if siteHazards.isEmpty {
                    Text(LocalizationKey.macNoData.localized).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(siteHazards.sorted { $0.riskLevel > $1.riskLevel }) { h in
                            HStack(spacing: 10) {
                                RiskChip(level: h.riskLevel)
                                Text(h.hazardDescription).font(.callout).lineLimit(1)
                                Spacer()
                                Text(h.correctiveActionStatus.localizedLabel)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            MacCard(title: LocalizationKey.macRelatedInspections.localized, systemImage: "checklist") {
                let related = inspections.filter { $0.siteId == site.id }.sorted { $0.startedAt > $1.startedAt }
                if related.isEmpty {
                    Text(LocalizationKey.macNoData.localized).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(related) { insp in
                            HStack {
                                Text(insp.areaName ?? LocalizationKey.inspectionNoArea.localized).font(.callout)
                                Spacer()
                                Text(insp.startedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Simple wrapping row of pill labels (areas, tags).
struct FlowRow: View {
    let items: [String]
    init(_ items: [String]) { self.items = items }
    var body: some View {
        WrappingHStack(items) { name in
            Text(name)
                .font(.callout)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(.background.tertiary, in: Capsule())
        }
    }
}
