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

        var blocks: [AnyView] = [AnyView(headerGrid(assessment))]
        blocks += items.enumerated().map { AnyView(row(step: $0.offset + 1, item: $0.element, method: assessment.method)) }
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

    private static func row(step: Int, item: RiskAssessmentItem, method: RiskAssessmentMethod) -> some View {
        HStack(spacing: 0) {
            Text("\(step)")
                .font(.system(size: 9, weight: .bold)).monospacedDigit()
                .foregroundStyle(Color.reportNavy)
                .padding(.horizontal, 4).padding(.vertical, 6)
                .frame(width: Col.step, alignment: .center)
            cell(item.taskDescription, Col.task)
            cell(item.hazardDescription, Col.hazards)
            cell(joinControls(item), Col.controls)
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
            Rectangle().fill(.black.opacity(0.12)).frame(height: 0.5)
        }
    }

    /// Current safety controls + the reduction measure (recommended controls), combined.
    private static func joinControls(_ item: RiskAssessmentItem) -> String {
        [item.currentControls, item.primaryCorrectiveAction?.measure]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: "\n")
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
