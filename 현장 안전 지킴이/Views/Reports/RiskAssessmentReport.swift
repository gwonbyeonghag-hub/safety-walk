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
        let dateText = (assessment.assessedAt ?? assessment.createdAt).formatted(date: .abbreviated, time: .omitted)
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
            (LocalizationKey.commonDone.localized, (a.assessedAt ?? a.createdAt).formatted(date: .abbreviated, time: .shortened)),
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
        HStack(alignment: .top, spacing: 0) {
            cell("\(index)", Col.no)
            cell(item.taskDescription, Col.task)
            cell(item.hazardDescription, Col.hazard)
            cell(item.currentControls ?? "", Col.controls)
            riskCell(item: item, method: method)
            // WO LEGAL-2c: preserve ALL 1:N 개선조치 — one aligned sub-row per action across the
            // reduction/owner/status columns (never collapse to a single primary action).
            actionColumns(item)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.black.opacity(0.12)).frame(height: 0.5)
        }
    }

    /// The reduction · owner · status columns, stacked one sub-row per corrective action so every
    /// action in the 1:N set is preserved and the three fields stay aligned per action.
    private static func actionColumns(_ item: RiskAssessmentItem) -> some View {
        let actions = item.sortedCorrectiveActions
        return VStack(spacing: 0) {
            if actions.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    cell("", Col.reduction)
                    ownerSubCell(nil)
                    cell("", Col.status)
                }
            } else {
                ForEach(actions) { a in
                    HStack(alignment: .top, spacing: 0) {
                        cell(a.measure ?? "", Col.reduction)
                        ownerSubCell(a)
                        cell(a.status.localizedLabel, Col.status)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(.black.opacity(0.06)).frame(height: 0.5)
                    }
                }
            }
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
            if let level = item.riskLevel {
                ReportRiskBand(level: level)
            } else {
                Text(LocalizationKey.raRiskUnassessed.localized)
                    .font(.system(size: 7)).foregroundStyle(.black.opacity(0.5))
            }
            if method.usesFrequencySeverity, let l = item.likelihood, let s = item.severity {
                Text("\(l)×\(s)=\(l * s)")
                    .font(.system(size: 6.5)).monospacedDigit()
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .padding(.horizontal, 2).padding(.vertical, 4)
        .frame(width: Col.risk, alignment: .center)
    }

    /// One action's 담당·기한 cell (nil = the no-actions placeholder row).
    private static func ownerSubCell(_ action: CorrectiveAction?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(action?.responsibleName?.isEmpty == false ? action!.responsibleName! : "—")
                .font(.system(size: 7))
            if let due = action?.dueDate {
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
