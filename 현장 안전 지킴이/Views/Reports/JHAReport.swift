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
        // WO LEGAL-3B §E: US 관할 JHA에만 표시 — jurisdictionSnapshot 으로 판별하는 단일 정책 지점.
        if JurisdictionPolicy.showsFederalNotice(assessment.jurisdictionSnapshot) {
            blocks.append(AnyView(USFederalNotice()))
        }
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
            // WO LEGAL-3A: 저장된 업종 스냅샷 — US 리포트라 특히 값어치가 크다(General Industry vs
            // Construction 등 임계값이 갈리는 근거).
            (LocalizationKey.raIndustry.localized,
             a.industryDisplayText),
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

    /// One job step → its own row (the step's current controls) plus one page-placeable row per
    /// corrective action (recommended control) — so every action in the 1:N set is preserved and can
    /// flow onto the next page instead of clipping.
    ///
    /// WO LEGAL-2c 5차 P1: every row REPEATS Step·Job Step·Hazards·Risk and varies only the Controls
    /// column. `ReportRenderer` packs blocks greedily with no notion of item boundaries, so a
    /// recommended-control row can open a page; without the step identity it would be unattributable.
    private static func rowBlocks(step: Int, item: RiskAssessmentItem, method: RiskAssessmentMethod) -> [AnyView] {
        let actions = CorrectiveActionPolicy.sortedCorrectiveActions(item)
        var blocks: [AnyView] = [AnyView(row(step: step, item: item, method: method,
                                             controlsLabel: LocalizationKey.raItemCurrentControls.localized,
                                             controls: item.currentControls ?? "",
                                             isItemEnd: actions.isEmpty))]
        for (i, action) in actions.enumerated() {
            blocks.append(AnyView(row(step: step, item: item, method: method,
                                      controlsLabel: LocalizationKey.raItemReduction.localized,
                                      controls: action.measure ?? "",
                                      isItemEnd: i == actions.count - 1)))
        }
        return blocks
    }

    /// A full-width row: Step·Job Step·Hazards·Risk (always, for per-page traceability) with `controls`
    /// holding either the step's current controls or one recommended control (a 개선조치's 감소대책).
    /// `controlsLabel` names which of the two this row is — the shared column header can't, so without it
    /// a reader landing on page 2 could not tell an existing control from a proposed one.
    private static func row(step: Int, item: RiskAssessmentItem, method: RiskAssessmentMethod,
                            controlsLabel: String, controls: String, isItemEnd: Bool) -> some View {
        HStack(spacing: 0) {
            Text("\(step)")
                .font(.system(size: 9, weight: .bold)).monospacedDigit()
                .foregroundStyle(Color.reportNavy)
                .padding(.horizontal, 4).padding(.vertical, 6)
                .frame(width: Col.step, alignment: .center)
            cell(item.taskDescription, Col.task)
            cell(item.hazardDescription, Col.hazards)
            controlsCell(label: controlsLabel, controls)
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

    /// The Controls cell: a small emphasized label naming the row's kind (현재 안전조치 / 감소대책) over the
    /// value. Reuses the existing item keys — the column header `report.jha.controls` is unchanged, and no
    /// new localization key is introduced. An empty value renders the shared 미기록 label, not a literal dash.
    private static func controlsCell(label: String, _ string: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 6.5, weight: .bold))
                .foregroundStyle(Color.reportNavy.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Text(string.isEmpty ? LocalizationKey.raNotRecorded.localized : string)
                .font(.system(size: 8.5))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4).padding(.vertical, 6)
        .frame(width: Col.controls, alignment: .leading)
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
