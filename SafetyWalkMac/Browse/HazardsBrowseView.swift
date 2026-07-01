import SwiftUI
import SwiftData
import SafetyWalkCore

struct HazardsBrowseView: View {
    @Query private var hazards: [Hazard]
    @Query private var sites: [Site]

    private var sorted: [Hazard] {
        hazards.sorted { a, b in
            a.riskLevel != b.riskLevel ? a.riskLevel > b.riskLevel : a.createdAt > b.createdAt
        }
    }

    var body: some View {
        BrowseLayout(items: sorted) { h in
            HStack(spacing: 8) {
                RiskDot(level: h.riskLevel, size: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(h.hazardDescription).font(.body).lineLimit(1)
                    Text(h.location).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        } detail: { h in
            detail(h)
        }
        .navigationTitle(LocalizationKey.macSectionHazards.localized)
    }

    @ViewBuilder
    private func detail(_ h: Hazard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                DetailHeader(title: h.hazardDescription)
                RiskChip(level: h.riskLevel)
            }
            MacCard {
                VStack(spacing: 6) {
                    DetailField(label: LocalizationKey.raSite.localized, value: siteName(h.siteId))
                    DetailField(label: LocalizationKey.hazardLocation.localized, value: h.location)
                    DetailField(label: LocalizationKey.hazardType.localized, value: typeLabel(h.type))
                    DetailField(label: LocalizationKey.hazardCorrectiveStatus.localized,
                                value: h.correctiveActionStatus.localizedLabel)
                    DetailField(label: LocalizationKey.commonDone.localized,
                                value: h.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
    }

    private func siteName(_ id: UUID) -> String { sites.first { $0.id == id }?.name ?? "—" }

    private func typeLabel(_ t: HazardType) -> String {
        switch t {
        case .fallRisk:   return LocalizationKey.hazardTypeFallRisk.localized
        case .electrical: return LocalizationKey.hazardTypeElectrical.localized
        case .fire:       return LocalizationKey.hazardTypeFire.localized
        case .chemical:   return LocalizationKey.hazardTypeChemical.localized
        case .general:    return LocalizationKey.hazardTypeGeneral.localized
        case .other:      return LocalizationKey.hazardTypeOther.localized
        }
    }
}
