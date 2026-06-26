import SwiftUI
import SafetyWalkCore
import UIKit

/// Pure-content SwiftUI view used by `InspectionExportService` to render the
/// report image / PDF. It owns no `@Query`, performs no async work, and has no
/// lifecycle hooks; all photos arrive preloaded as `UIImage`s.
struct InspectionReportView: View {

    static let pageWidth: CGFloat = 595

    let inspection: Inspection
    let itemPhotos: [UUID: UIImage]
    let hazardPhotos: [UUID: UIImage]

    private let pagePadding: CGFloat = 22
    private let tableLine = Color(white: 0.78)
    private let quietText = Color(white: 0.34)
    private let faintFill = Color(white: 0.96)
    private let navy = Color(red: 0.13, green: 0.24, blue: 0.33)
    private let generatedAt = Date()

    // MARK: - Derived

    private var items: [ChecklistItem] {
        inspection.items.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var hazards: [Hazard] {
        inspection.hazards.sorted { $0.createdAt > $1.createdAt }
    }

    private var groupedItems: [(category: String, items: [ChecklistItem])] {
        var order: [String] = []
        var buckets: [String: [ChecklistItem]] = [:]
        for item in items {
            if buckets[item.category] == nil {
                order.append(item.category)
                buckets[item.category] = []
            }
            buckets[item.category]?.append(item)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    private var passCount: Int { items.filter { $0.result == .pass }.count }
    private var failCount: Int { items.filter { $0.result == .fail }.count }
    private var naCount: Int { items.filter { $0.result == .notApplicable }.count }
    private var uncheckedCount: Int { items.filter { $0.result == .unchecked }.count }
    private var checkedCount: Int { items.count - uncheckedCount }
    private var openHazardCount: Int {
        hazards.filter { $0.correctiveActionStatus != .completed }.count
    }

    private var passRate: Int {
        guard checkedCount > 0 else { return 0 }
        return Int((Double(passCount) / Double(checkedCount) * 100).rounded())
    }

    private var progressRate: Int {
        guard !items.isEmpty else { return 0 }
        return Int((Double(checkedCount) / Double(items.count) * 100).rounded())
    }

    private var highHazards: Int { hazards.filter { $0.riskLevel == .high }.count }
    private var mediumHazards: Int { hazards.filter { $0.riskLevel == .medium }.count }
    private var lowHazards: Int { hazards.filter { $0.riskLevel == .low }.count }

    private var evidenceItems: [ReportEvidence] {
        let checklistPhotos = items.compactMap { item -> ReportEvidence? in
            guard let image = itemPhotos[item.id] else { return nil }
            return ReportEvidence(
                id: item.id,
                caption: L(item.title),
                detail: L(item.category),
                image: image
            )
        }
        let hazardPhotoItems = hazards.compactMap { hazard -> ReportEvidence? in
            guard let image = hazardPhotos[hazard.id] else { return nil }
            return ReportEvidence(
                id: hazard.id,
                caption: hazard.hazardDescription,
                detail: hazard.location,
                image: image
            )
        }
        return checklistPhotos + hazardPhotoItems
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            masthead
            metadataTable
            resultSummarySection
            hazardSummarySection
            categoryResultsSection
            if !hazards.isEmpty {
                hazardActionsSection
            }
            evidencePhotosSection
            disclaimerSection
            footer
        }
        .padding(pagePadding)
        .frame(width: Self.pageWidth, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(red: 0.13, green: 0.24, blue: 0.33))
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizationKey.reportTitle.localized)
                        .font(.system(size: 22, weight: .bold))
                    Text(reportSubtitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(quietText)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(LocalizationKey.reportGeneratedAt.localized)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(quietText)
                    Text(shortFormatted(generatedAt))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.black)
                }
            }

            statusStrip
        }
        .padding(14)
        .background(Color(red: 0.93, green: 0.96, blue: 0.97))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.58, green: 0.67, blue: 0.72), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var reportSubtitle: String {
        if let area = inspection.areaName, !area.isEmpty {
            return "\(inspection.siteName) / \(area)"
        }
        return inspection.siteName
    }

    private var statusStrip: some View {
        HStack(spacing: 0) {
            stripMetric(
                title: LocalizationKey.reportPassRate.localized,
                value: "\(passRate)%",
                color: Color.green
            )
            stripDivider
            stripMetric(
                title: LocalizationKey.reportOpenHazards.localized,
                value: "\(openHazardCount)",
                color: openHazardCount > 0 ? Color.orange : Color.green
            )
            stripDivider
            stripMetric(
                title: LocalizationKey.reportProgress.localized,
                value: "\(checkedCount)/\(items.count)",
                color: Color(red: 0.13, green: 0.24, blue: 0.33)
            )
        }
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func stripMetric(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 7.5, weight: .medium))
                .foregroundStyle(quietText)
        }
        .frame(maxWidth: .infinity)
    }

    private var stripDivider: some View {
        Rectangle()
            .fill(tableLine)
            .frame(width: 0.6, height: 28)
    }

    // MARK: - Metadata

    private var metadataTable: some View {
        reportSection(LocalizationKey.reportMetadata.localized) {
            VStack(spacing: 0) {
                tablePairRow(
                    leftLabel: LocalizationKey.summaryInspector.localized,
                    leftValue: emptyDash(inspection.inspectorName),
                    rightLabel: LocalizationKey.reportChecklist.localized,
                    rightValue: inspection.templateId
                )
                tablePairRow(
                    leftLabel: LocalizationKey.summaryStartedAt.localized,
                    leftValue: shortFormatted(inspection.startedAt),
                    rightLabel: LocalizationKey.summaryCompletedAt.localized,
                    rightValue: inspection.completedAt.map(shortFormatted) ?? "-"
                )
                tablePairRow(
                    leftLabel: LocalizationKey.reportStatus.localized,
                    leftValue: localizedInspectionStatus(inspection.status),
                    rightLabel: LocalizationKey.reportArea.localized,
                    rightValue: inspection.areaName?.isEmpty == false
                        ? inspection.areaName ?? "-"
                        : LocalizationKey.inspectionNoArea.localized
                )
            }
            .tableBorder(line: tableLine)
        }
    }

    private func tablePairRow(
        leftLabel: String,
        leftValue: String,
        rightLabel: String,
        rightValue: String
    ) -> some View {
        HStack(spacing: 0) {
            metadataCell(label: leftLabel, value: leftValue)
            metadataCell(label: rightLabel, value: rightValue)
        }
        .rowDivider(line: tableLine)
    }

    private func metadataCell(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(quietText)
                .frame(width: 70, alignment: .leading)
                .padding(7)
                .background(faintFill)
            Text(value)
                .font(.system(size: 8.5))
                .foregroundStyle(Color.black)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(7)
        }
        .frame(maxWidth: .infinity)
        .columnDivider(line: tableLine)
    }

    // MARK: - Summary

    private var resultSummarySection: some View {
        reportSection(LocalizationKey.reportResultSummary.localized) {
            HStack(spacing: 0) {
                summaryCell(LocalizationKey.summaryPass.localized, "\(passCount)", Color.green)
                summaryCell(LocalizationKey.summaryFail.localized, "\(failCount)", Color.red)
                summaryCell(LocalizationKey.summaryNotApplicable.localized, "\(naCount)", Color(white: 0.42))
                summaryCell(LocalizationKey.reportUnchecked.localized, "\(uncheckedCount)", Color(white: 0.46))
                summaryCell(LocalizationKey.reportProgressRate.localized, "\(progressRate)%", navy)
            }
            .tableBorder(line: tableLine)
        }
    }

    // Hazard counts are reported tallies, never a verdict — kept in their own
    // labeled block (separate from checklist results) per the report spec.
    private var hazardSummarySection: some View {
        reportSection(LocalizationKey.reportHazardSummary.localized) {
            HStack(spacing: 0) {
                summaryCell(LocalizationKey.riskHigh.localized, "\(highHazards)", Color.red)
                summaryCell(LocalizationKey.riskMedium.localized, "\(mediumHazards)", Color.orange)
                summaryCell(LocalizationKey.riskLow.localized, "\(lowHazards)", riskColor(.low))
            }
            .tableBorder(line: tableLine)
        }
    }

    private func summaryCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7.5, weight: .medium))
                .foregroundStyle(quietText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .columnDivider(line: tableLine)
    }

    // MARK: - Checklist results

    private var categoryResultsSection: some View {
        reportSection(LocalizationKey.reportCategoryResults.localized) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(groupedItems, id: \.category) { group in
                    categoryTable(category: group.category, items: group.items)
                }
            }
        }
    }

    private func categoryTable(category: String, items: [ChecklistItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L(category))
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color(red: 0.13, green: 0.24, blue: 0.33))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.92, green: 0.95, blue: 0.96))

            checklistHeaderRow

            ForEach(items) { item in
                checklistItemRow(item)
            }
        }
        .tableBorder(line: tableLine)
    }

    private var checklistHeaderRow: some View {
        HStack(spacing: 0) {
            tableHeader(LocalizationKey.reportChecklistItem.localized, width: nil)
            tableHeader(LocalizationKey.reportResult.localized, width: 70)
            tableHeader(LocalizationKey.reportNote.localized, width: 112)
        }
        .rowDivider(line: tableLine)
    }

    private func checklistItemRow(_ item: ChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 0) {
            tableText(L(item.title), width: nil)
            resultBadge(item.result)
                .frame(width: 70)
                .padding(.vertical, 5)
                .columnDivider(line: tableLine)
            tableText(emptyDash(item.note ?? ""), width: 112)
        }
        .rowDivider(line: tableLine)
    }

    // MARK: - Hazards

    private var hazardActionsSection: some View {
        reportSection(LocalizationKey.reportHazardsAndActions.localized) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tableHeader(LocalizationKey.hazardDescription.localized, width: nil)
                    tableHeader(LocalizationKey.hazardType.localized, width: 72)
                    tableHeader(LocalizationKey.hazardRiskLevel.localized, width: 52)
                    tableHeader(LocalizationKey.hazardLocation.localized, width: 86)
                    tableHeader(LocalizationKey.hazardCorrectiveStatus.localized, width: 72)
                    tableHeader(LocalizationKey.hazardCreatedAt.localized, width: 62)
                }
                .rowDivider(line: tableLine)

                ForEach(hazards) { hazard in
                    hazardTableRow(hazard)
                }
            }
            .tableBorder(line: tableLine)
        }
    }

    private func hazardTableRow(_ hazard: Hazard) -> some View {
        HStack(alignment: .top, spacing: 0) {
            tableText(hazard.hazardDescription, width: nil)
            tableText(localizedHazardType(hazard.type), width: 72)
            riskBadge(hazard.riskLevel)
                .frame(width: 52)
                .padding(.vertical, 5)
                .columnDivider(line: tableLine)
            tableText(hazard.location, width: 86)
            tableText(localizedCorrectiveStatus(hazard.correctiveActionStatus), width: 72)
            tableText(dateOnly(hazard.createdAt), width: 62)
        }
        .rowDivider(line: tableLine)
    }

    // MARK: - Evidence

    private var evidencePhotosSection: some View {
        reportSection(LocalizationKey.reportEvidencePhotos.localized) {
            if evidenceItems.isEmpty {
                Text(LocalizationKey.reportNoEvidencePhotos.localized)
                    .font(.system(size: 8.5))
                    .foregroundStyle(quietText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tableBorder(line: tableLine)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(evidenceItems) { evidence in
                        evidenceCard(evidence)
                    }
                }
            }
        }
    }

    private func evidenceCard(_ evidence: ReportEvidence) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(uiImage: evidence.image)
                .resizable()
                .scaledToFill()
                .frame(height: 86)
                .frame(maxWidth: .infinity)
                .clipped()
                .background(Color(white: 0.92))

            Text(evidence.caption)
                .font(.system(size: 7.5, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(evidence.detail)
                .font(.system(size: 7))
                .foregroundStyle(quietText)
                .lineLimit(1)
        }
        .padding(6)
        .tableBorder(line: tableLine)
    }

    // MARK: - Disclaimer and footer

    private var disclaimerSection: some View {
        reportSection(LocalizationKey.disclaimerTitle.localized) {
            Text(LocalizationKey.disclaimerText.localized)
                .font(.system(size: 8))
                .foregroundStyle(Color(white: 0.32))
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 1.0, green: 0.98, blue: 0.91))
                .tableBorder(line: Color(red: 0.88, green: 0.78, blue: 0.48))
        }
    }

    private var footer: some View {
        HStack {
            Text(LocalizationKey.reportGeneratedBy.localized)
            Spacer()
            Text(shortFormatted(generatedAt))
        }
        .font(.system(size: 7.5))
        .foregroundStyle(Color(white: 0.42))
        .padding(.top, 4)
    }

    // MARK: - Shared table views

    private func reportSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 6)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color(red: 0.13, green: 0.24, blue: 0.33))
                        .frame(width: 3)
                }
            content()
        }
    }

    private func tableHeader(_ text: String, width: CGFloat?) -> some View {
        Text(text)
            .font(.system(size: 7.5, weight: .bold))
            .foregroundStyle(Color(white: 0.26))
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(faintFill)
            .columnDivider(line: tableLine)
    }

    private func tableText(_ text: String, width: CGFloat?) -> some View {
        Text(text)
            .font(.system(size: 7.5))
            .foregroundStyle(Color.black)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .columnDivider(line: tableLine)
    }

    private func resultBadge(_ result: ChecklistItemResult) -> some View {
        Text(localizedResult(result))
            .font(.system(size: 7.5, weight: .bold))
            .foregroundStyle(resultColor(result))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func riskBadge(_ level: RiskLevel) -> some View {
        Text(localizedRiskLevel(level))
            .font(.system(size: 7.5, weight: .bold))
            .foregroundStyle(riskColor(level))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    // MARK: - Formatting and labels

    private func shortFormatted(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }

    private func dateOnly(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
    }

    private func emptyDash(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : value
    }

    private func localizedInspectionStatus(_ status: InspectionStatus) -> String {
        switch status {
        case .inProgress: return LocalizationKey.inspectionStatusInProgress.localized
        case .completed: return LocalizationKey.inspectionStatusCompleted.localized
        }
    }

    private func localizedResult(_ result: ChecklistItemResult) -> String {
        switch result {
        case .pass: return LocalizationKey.checklistPass.localized
        case .fail: return LocalizationKey.checklistFail.localized
        case .notApplicable: return LocalizationKey.checklistNotApplicable.localized
        case .unchecked: return LocalizationKey.reportUnchecked.localized
        }
    }

    private func resultColor(_ result: ChecklistItemResult) -> Color {
        switch result {
        case .pass: return Color.green
        case .fail: return Color.red
        case .notApplicable: return Color(white: 0.42)
        case .unchecked: return Color(white: 0.50)
        }
    }

    private func localizedRiskLevel(_ level: RiskLevel) -> String {
        switch level {
        case .low: return LocalizationKey.riskLow.localized
        case .medium: return LocalizationKey.riskMedium.localized
        case .high: return LocalizationKey.riskHigh.localized
        }
    }

    private func riskColor(_ level: RiskLevel) -> Color {
        switch level {
        case .low: return Color(red: 0.70, green: 0.52, blue: 0.00)
        case .medium: return Color.orange
        case .high: return Color.red
        }
    }

    private func localizedHazardType(_ type: HazardType) -> String {
        switch type {
        case .fallRisk: return LocalizationKey.hazardTypeFallRisk.localized
        case .electrical: return LocalizationKey.hazardTypeElectrical.localized
        case .fire: return LocalizationKey.hazardTypeFire.localized
        case .chemical: return LocalizationKey.hazardTypeChemical.localized
        case .general: return LocalizationKey.hazardTypeGeneral.localized
        case .other: return LocalizationKey.hazardTypeOther.localized
        }
    }

    private func localizedCorrectiveStatus(_ status: CorrectiveActionStatus) -> String {
        switch status {
        case .notStarted: return LocalizationKey.statusNotStarted.localized
        case .inProgress: return LocalizationKey.statusInProgress.localized
        case .completed: return LocalizationKey.statusCompleted.localized
        }
    }
}

private struct ReportEvidence: Identifiable {
    let id: UUID
    let caption: String
    let detail: String
    let image: UIImage
}

private extension View {
    func tableBorder(line: Color) -> some View {
        overlay(
            Rectangle()
                .stroke(line, lineWidth: 0.6)
        )
    }

    func rowDivider(line: Color) -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(line)
                .frame(height: 0.6)
        }
    }

    func columnDivider(line: Color) -> some View {
        overlay(alignment: .trailing) {
            Rectangle()
                .fill(line)
                .frame(width: 0.6)
        }
    }
}
