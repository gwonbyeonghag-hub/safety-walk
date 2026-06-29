import SwiftUI
import SafetyWalkCore

/// 위험성평가표 (KR, A4) — WO-5b. Read-only multi-page render of a RiskAssessment via the
/// shared ReportRenderer. Column header repeats on every page; rows never split.
@MainActor
enum RiskAssessmentReport {

    // Column widths (pt). Each includes its own padding; sum ≈ A4 content width (523).
    private enum Col {
        static let no: CGFloat = 18
        static let task: CGFloat = 74
        static let hazard: CGFloat = 96
        static let controls: CGFloat = 80
        static let risk: CGFloat = 52
        static let reduction: CGFloat = 96
        static let owner: CGFloat = 60
        static let status: CGFloat = 38
    }

    static func pdfURL(for assessment: RiskAssessment) -> URL? {
        let items = (assessment.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RiskAssessment-\(assessment.id.uuidString).pdf")
        let dateText = assessment.assessedAt.formatted(date: .abbreviated, time: .omitted)
        let subtitle = assessment.siteName.isEmpty ? dateText : "\(assessment.siteName) · \(dateText)"

        var blocks: [AnyView] = [AnyView(headerGrid(assessment))]
        blocks += items.enumerated().map { AnyView(row(index: $0.offset + 1, item: $0.element, method: assessment.method)) }
        blocks.append(AnyView(ReportDisclaimer()))

        return ReportRenderer.renderPDF(
            to: url,
            pageSize: ReportPaper.a4,
            masthead: AnyView(ReportMasthead(title: LocalizationKey.reportRaTitle.localized, subtitle: subtitle)),
            subhead: AnyView(columnHeader()),
            footer: { page, total in AnyView(ReportFooter(page: page, total: total)) },
            blocks: blocks
        ) ? url : nil
    }

    private static func headerGrid(_ a: RiskAssessment) -> some View {
        ReportInfoGrid(pairs: [
            (LocalizationKey.raSite.localized, a.siteName.isEmpty ? "—" : a.siteName),
            (LocalizationKey.raAssessor.localized, a.assessorName.isEmpty ? "—" : a.assessorName),
            (LocalizationKey.raKind.localized, a.kind.localizedLabel),
            (LocalizationKey.raMethod.localized, a.method.localizedLabel),
            (LocalizationKey.commonDone.localized, a.assessedAt.formatted(date: .abbreviated, time: .shortened)),
        ])
    }

    private static func columnHeader() -> some View {
        HStack(spacing: 0) {
            head(LocalizationKey.reportNo.localized, Col.no)
            head(LocalizationKey.raItemTask.localized, Col.task)
            head(LocalizationKey.raItemHazard.localized, Col.hazard)
            head(LocalizationKey.raItemCurrentControls.localized, Col.controls)
            head(LocalizationKey.reportJhaRisk.localized, Col.risk)
            head(LocalizationKey.raItemReduction.localized, Col.reduction)
            head(LocalizationKey.reportRaOwner.localized, Col.owner)
            head(LocalizationKey.raItemStatus.localized, Col.status)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.reportNavy.opacity(0.12))
    }

    private static func head(_ text: String, _ width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 7.5, weight: .bold))
            .foregroundStyle(Color.reportNavy)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3).padding(.vertical, 4)
            .frame(width: width, alignment: .leading)
    }

    private static func row(index: Int, item: RiskAssessmentItem, method: RiskAssessmentMethod) -> some View {
        HStack(spacing: 0) {
            cell("\(index)", Col.no)
            cell(item.taskDescription, Col.task)
            cell(item.hazardDescription, Col.hazard)
            cell(item.currentControls ?? "", Col.controls)
            riskCell(item: item, method: method)
            cell(item.reductionMeasure ?? "", Col.reduction)
            ownerCell(item)
            cell(item.correctiveActionStatus.localizedLabel, Col.status)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.black.opacity(0.12)).frame(height: 0.5)
        }
    }

    private static func cell(_ string: String, _ width: CGFloat) -> some View {
        Text(string.isEmpty ? "—" : string)
            .font(.system(size: 7.5))
            .monospacedDigit()
            .foregroundStyle(.black)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3).padding(.vertical, 4)
            .frame(width: width, alignment: .leading)
    }

    private static func riskCell(item: RiskAssessmentItem, method: RiskAssessmentMethod) -> some View {
        VStack(spacing: 2) {
            ReportRiskBand(level: item.riskLevel)
            if method.usesFrequencySeverity, let l = item.likelihood, let s = item.severity {
                Text("\(l)×\(s)=\(l * s)")
                    .font(.system(size: 6.5)).monospacedDigit()
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .padding(.horizontal, 2).padding(.vertical, 4)
        .frame(width: Col.risk, alignment: .center)
    }

    private static func ownerCell(_ item: RiskAssessmentItem) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text((item.responsibleName?.isEmpty == false ? item.responsibleName! : "—"))
                .font(.system(size: 7))
            if let due = item.dueDate {
                Text(due.formatted(date: .numeric, time: .omitted))
                    .font(.system(size: 6.5)).monospacedDigit()
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 3).padding(.vertical, 4)
        .frame(width: Col.owner, alignment: .leading)
    }
}
