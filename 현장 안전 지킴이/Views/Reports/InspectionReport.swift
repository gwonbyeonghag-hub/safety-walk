import SwiftUI
import UIKit
import SafetyWalkCore

/// 점검 리포트 (A4) — WO-5b migration to the multi-page engine. Category sections, item
/// rows with result badges, evidence photos, and the hazards section — all as paginated
/// blocks (photos included). Photos are preloaded UIImages (iOS); the engine itself is
/// cross-platform.
@MainActor
enum InspectionReport {

    static func pdfURL(inspection: Inspection,
                       itemPhotos: [UUID: UIImage],
                       hazardPhotos: [UUID: UIImage]) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SafetyWalk-Inspection-\(inspection.id.uuidString).pdf")
        let dateText = inspection.startedAt.formatted(date: .abbreviated, time: .omitted)
        let subtitle = "\(inspection.siteName) · \(dateText)"

        var blocks: [AnyView] = [AnyView(headerGrid(inspection))]

        for group in grouped(inspection.items) {
            blocks.append(AnyView(sectionTitle(L(group.category))))
            for item in group.items {
                blocks.append(AnyView(itemRow(item)))
                if let image = itemPhotos[item.id] {
                    blocks.append(AnyView(photoBlock(image, caption: L(item.title))))
                }
            }
        }

        let hazards = inspection.hazards.sorted { $0.createdAt < $1.createdAt }
        if !hazards.isEmpty {
            blocks.append(AnyView(sectionTitle(LocalizationKey.reportHazardsAndActions.localized)))
            for hazard in hazards {
                blocks.append(AnyView(hazardRow(hazard)))
                if let image = hazardPhotos[hazard.id] {
                    blocks.append(AnyView(photoBlock(image, caption: hazard.hazardDescription)))
                }
            }
        }

        blocks.append(AnyView(ReportDisclaimer()))

        return ReportRenderer.renderPDF(
            to: url,
            pageSize: ReportPaper.a4,
            masthead: AnyView(ReportMasthead(title: LocalizationKey.reportTitle.localized, subtitle: subtitle)),
            footer: { page, total in AnyView(ReportFooter(page: page, total: total)) },
            blocks: blocks
        ) ? url : nil
    }

    // MARK: - Grouping (preserve category order of first appearance)

    private static func grouped(_ items: [ChecklistItem]) -> [(category: String, items: [ChecklistItem])] {
        var order: [String] = []
        var buckets: [String: [ChecklistItem]] = [:]
        for item in items.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            if buckets[item.category] == nil { order.append(item.category); buckets[item.category] = [] }
            buckets[item.category]?.append(item)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    // MARK: - Blocks

    private static func headerGrid(_ i: Inspection) -> some View {
        ReportInfoGrid(pairs: [
            (LocalizationKey.raSite.localized, i.siteName),
            (LocalizationKey.reportArea.localized, i.areaName?.isEmpty == false ? i.areaName! : LocalizationKey.inspectionNoArea.localized),
            (LocalizationKey.summaryInspector.localized, i.inspectorName.isEmpty ? "—" : i.inspectorName),
            (LocalizationKey.reportStatus.localized, status(i.status)),
            (LocalizationKey.commonDone.localized, i.startedAt.formatted(date: .abbreviated, time: .shortened)),
        ])
    }

    private static func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.reportNavy.opacity(0.85))
    }

    private static func itemRow(_ item: ChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L(item.title))
                    .font(.system(size: 9))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                resultBadge(item.result)
            }
            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 8))
                    .foregroundStyle(.black.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.1)).frame(height: 0.5) }
    }

    private static func hazardRow(_ h: Hazard) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(h.hazardDescription)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                ReportRiskBand(level: h.riskLevel)
            }
            HStack(spacing: 10) {
                metaLabel(LocalizationKey.hazardLocation.localized, h.location)
                metaLabel(LocalizationKey.hazardType.localized, hazardType(h.type))
                metaLabel(LocalizationKey.hazardCorrectiveStatus.localized, correctiveStatus(h.correctiveActionStatus))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.1)).frame(height: 0.5) }
    }

    private static func metaLabel(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 7.5, weight: .semibold)).foregroundStyle(Color.reportNavy)
            Text(value.isEmpty ? "—" : value).font(.system(size: 7.5)).foregroundStyle(.black.opacity(0.75))
        }
    }

    private static func photoBlock(_ image: UIImage, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240, maxHeight: 170, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(caption)
                .font(.system(size: 7.5))
                .foregroundStyle(.black.opacity(0.6))
                .lineLimit(2)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Labels

    private static func resultBadge(_ r: ChecklistItemResult) -> some View {
        Text(resultLabel(r))
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(resultColor(r), in: Capsule())
            .fixedSize()
    }

    private static func resultLabel(_ r: ChecklistItemResult) -> String {
        switch r {
        case .pass: return LocalizationKey.checklistPass.localized
        case .fail: return LocalizationKey.checklistFail.localized
        case .notApplicable: return LocalizationKey.checklistNotApplicable.localized
        case .unchecked: return LocalizationKey.reportUnchecked.localized
        }
    }

    private static func resultColor(_ r: ChecklistItemResult) -> Color {
        switch r {
        case .pass: return .green
        case .fail: return .red
        case .notApplicable, .unchecked: return Color(white: 0.45)
        }
    }

    private static func status(_ s: InspectionStatus) -> String {
        s == .completed ? LocalizationKey.inspectionStatusCompleted.localized
                        : LocalizationKey.inspectionStatusInProgress.localized
    }

    private static func hazardType(_ t: HazardType) -> String {
        switch t {
        case .fallRisk: return LocalizationKey.hazardTypeFallRisk.localized
        case .electrical: return LocalizationKey.hazardTypeElectrical.localized
        case .fire: return LocalizationKey.hazardTypeFire.localized
        case .chemical: return LocalizationKey.hazardTypeChemical.localized
        case .general: return LocalizationKey.hazardTypeGeneral.localized
        case .other: return LocalizationKey.hazardTypeOther.localized
        }
    }

    private static func correctiveStatus(_ s: CorrectiveActionStatus) -> String {
        switch s {
        case .notStarted: return LocalizationKey.statusNotStarted.localized
        case .inProgress: return LocalizationKey.statusInProgress.localized
        case .completed: return LocalizationKey.statusCompleted.localized
        }
    }
}
