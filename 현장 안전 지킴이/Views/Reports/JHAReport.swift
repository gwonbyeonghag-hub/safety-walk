import SwiftUI
import SafetyWalkCore

/// JHA / JHA worksheet (US, Letter) — WO-5b. Ordered job steps with hazards, controls,
/// and risk. OSHA-friendly labels (report.jha.*). Same engine, Letter paper.
@MainActor
enum JHAReport {

    // Column widths (pt). Sum ≈ Letter content width (612 − 2×36 = 540).
    private enum Col {
        static let step: CGFloat = 38
        static let task: CGFloat = 128
        static let hazards: CGFloat = 140
        static let controls: CGFloat = 138
        static let risk: CGFloat = 72
    }

    static func pdfURL(for assessment: RiskAssessment) -> URL? {
        let items = (assessment.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("JHA-\(assessment.id.uuidString).pdf")
        let dateText = (assessment.assessedAt ?? assessment.createdAt).formatted(date: .abbreviated, time: .omitted)
        let subtitle = assessment.siteName.isEmpty ? dateText : "\(assessment.siteName) · \(dateText)"

        // WO LEGAL-2c 반송 4차 P1: one block per corrective action (recommended control) so the whole
        // 1:N set paginates instead of being crammed into a single merged, clippable controls cell.
        var blocks: [AnyView] = [AnyView(headerGrid(assessment))]
        for (offset, item) in items.enumerated() {
            blocks += rowBlocks(step: offset + 1, item: item, method: assessment.method)
        }
        blocks.append(AnyView(ReportDisclaimer()))

        return ReportRenderer.renderPDF(
            to: url,
            pageSize: ReportPaper.usLetter,
            masthead: AnyView(ReportMasthead(title: LocalizationKey.reportJhaTitle.localized, subtitle: subtitle)),
            subhead: AnyView(columnHeader()),
            footer: { page, total in AnyView(ReportFooter(page: page, total: total)) },
            blocks: blocks
        ) ? url : nil
    }

    private static func headerGrid(_ a: RiskAssessment) -> some View {
        ReportInfoGrid(pairs: [
            (LocalizationKey.raSite.localized, a.siteName.isEmpty ? "—" : a.siteName),
            (LocalizationKey.raAssessor.localized, a.assessorName.isEmpty ? "—" : a.assessorName),
            (LocalizationKey.commonDone.localized, (a.assessedAt ?? a.createdAt).formatted(date: .abbreviated, time: .shortened)),
            (LocalizationKey.raMethod.localized, a.method.localizedLabel),
        ])
    }

    private static func columnHeader() -> some View {
        HStack(spacing: 0) {
            head(LocalizationKey.reportJhaStep.localized, Col.step)
            head(LocalizationKey.reportJhaJobStep.localized, Col.task)
            head(LocalizationKey.reportJhaHazards.localized, Col.hazards)
            head(LocalizationKey.reportJhaControls.localized, Col.controls)
            head(LocalizationKey.reportJhaRisk.localized, Col.risk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.reportNavy.opacity(0.12))
    }

    private static func head(_ text: String, _ width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(Color.reportNavy)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4).padding(.vertical, 5)
            .frame(width: width, alignment: .leading)
    }

    /// Width of the leading columns (Step·Job Step·Hazards) — a recommended-control row spans this with
    /// a clear spacer so its measure sits under the Controls header (mirrors RiskAssessmentReport.leadingWidth).
    private static let leadingWidth = Col.step + Col.task + Col.hazards

    /// One job step → its item row plus one page-placeable row per corrective action (recommended
    /// control). The controls column reads top-to-bottom: the step's own controls, then each measure —
    /// so every action in the 1:N set is preserved and can flow onto the next page instead of clipping.
    private static func rowBlocks(step: Int, item: RiskAssessmentItem, method: RiskAssessmentMethod) -> [AnyView] {
        let actions = CorrectiveActionPolicy.sortedCorrectiveActions(item)
        var blocks: [AnyView] = [AnyView(itemRow(step: step, item: item, method: method, isItemEnd: actions.isEmpty))]
        for (i, action) in actions.enumerated() {
            blocks.append(AnyView(actionRow(action: action, isItemEnd: i == actions.count - 1)))
        }
        return blocks
    }

    private static func itemRow(step: Int, item: RiskAssessmentItem, method: RiskAssessmentMethod, isItemEnd: Bool) -> some View {
        HStack(spacing: 0) {
            Text("\(step)")
                .font(.system(size: 9, weight: .bold)).monospacedDigit()
                .foregroundStyle(Color.reportNavy)
                .padding(.horizontal, 4).padding(.vertical, 6)
                .frame(width: Col.step, alignment: .center)
            cell(item.taskDescription, Col.task)
            cell(item.hazardDescription, Col.hazards)
            cell(item.currentControls ?? "", Col.controls)   // step's own controls; measures follow as rows
            VStack(spacing: 2) {
                if let level = item.riskLevel {
                    ReportRiskBand(level: level)
                } else {
                    Text(LocalizationKey.raRiskUnassessed.localized)
                        .font(.system(size: 7.5)).foregroundStyle(.black.opacity(0.5))
                }
                if method.usesFrequencySeverity, let l = item.likelihood, let s = item.severity {
                    Text("\(l)×\(s)=\(l * s)")
                        .font(.system(size: 7)).monospacedDigit()
                        .foregroundStyle(.black.opacity(0.6))
                }
            }
            .padding(.horizontal, 3).padding(.vertical, 6)
            .frame(width: Col.risk, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.black.opacity(isItemEnd ? 0.12 : 0.06)).frame(height: 0.5)
        }
    }

    /// A recommended-control row: one corrective action's measure in the Controls column, aligned under
    /// its header via a clear leading spacer; step/task/hazards/risk are blank (continuation of the step).
    private static func actionRow(action: CorrectiveAction, isItemEnd: Bool) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: leadingWidth, height: 1)
            cell(action.measure ?? "", Col.controls)
            Color.clear.frame(width: Col.risk, height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.black.opacity(isItemEnd ? 0.12 : 0.06)).frame(height: 0.5)
        }
    }

    private static func cell(_ string: String, _ width: CGFloat) -> some View {
        Text(string.isEmpty ? "—" : string)
            .font(.system(size: 8.5))
            .foregroundStyle(.black)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4).padding(.vertical, 6)
            .frame(width: width, alignment: .leading)
    }
}
