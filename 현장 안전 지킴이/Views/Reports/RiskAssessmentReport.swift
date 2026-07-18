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

        // WO LEGAL-2c 반송 4차 P1: emit ONE block per corrective action (not one block per item) so a
        // long 1:N set is paginated across pages instead of clipped inside a single unsplittable row.
        var blocks: [AnyView] = [AnyView(headerGrid(assessment))]
        for (offset, item) in items.enumerated() {
            blocks += rowBlocks(index: offset + 1, item: item, method: assessment.method)
        }
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

    /// One item → 1..N page-placeable row blocks, one per corrective action (deterministic order);
    /// zero actions → a single row with the 미기록 action columns.
    ///
    /// WO LEGAL-2c 5차 P1: every row REPEATS the item columns (번호·공정·작업·유해위험요인·현재
    /// 안전조치·위험성). `ReportRenderer` packs blocks greedily and knows nothing about item boundaries,
    /// so any row can land at the top of a page — a row that omitted the item info would be unreadable
    /// there. Repeating costs a few extra pages and buys per-page traceability, which a 위험성평가표
    /// (a legal record) needs. The heavy separator still marks where an item ends.
    private static func rowBlocks(index: Int, item: RiskAssessmentItem, method: RiskAssessmentMethod) -> [AnyView] {
        let actions = CorrectiveActionPolicy.sortedCorrectiveActions(item)
        guard !actions.isEmpty else {
            return [AnyView(rowBlock(index: index, item: item, method: method,
                                     action: nil, isItemEnd: true))]
        }
        return actions.enumerated().map { i, action in
            AnyView(rowBlock(index: index, item: item, method: method,
                             action: action, isItemEnd: i == actions.count - 1))
        }
    }

    /// A full-width row: the item columns (always) + one action's reduction·owner·status.
    /// `isItemEnd` draws the item separator; inner rows draw a hairline.
    private static func rowBlock(index: Int, item: RiskAssessmentItem, method: RiskAssessmentMethod,
                                 action: CorrectiveAction?, isItemEnd: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            cell("\(index)", Col.no)
            cell(item.taskDescription, Col.task)
            cell(item.hazardDescription, Col.hazard)
            cell(item.currentControls ?? "", Col.controls)
            riskCell(item: item, method: method)
            actionCell(action?.measure, Col.reduction)                                  // 감소대책 (P3: 빈 셀 → 미기록)
            ownerSubCell(action)                                                         // 담당·기한 (P3: 빈 담당 → 미기록)
            actionCell(action.map { $0.status.localizedLabel }, Col.status)             // 상태
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.black.opacity(isItemEnd ? 0.12 : 0.06)).frame(height: 0.5)
        }
    }

    /// An action-column cell: like `cell` but an empty/absent value renders the shared 미기록 label
    /// (WO LEGAL-2c 반송 4차 P3 — no literal "—" on the changed action paths).
    private static func actionCell(_ text: String?, _ width: CGFloat) -> some View {
        Text(text?.isEmpty == false ? text! : LocalizationKey.raNotRecorded.localized)
            .font(.system(size: 7.5))
            .foregroundStyle(.black)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3).padding(.vertical, 4)
            .frame(width: width, alignment: .leading)
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

    /// One action's 담당·기한 cell (nil = the no-actions placeholder row). P3: empty owner → 미기록.
    private static func ownerSubCell(_ action: CorrectiveAction?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(action?.responsibleName?.isEmpty == false ? action!.responsibleName! : LocalizationKey.raNotRecorded.localized)
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
