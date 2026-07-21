import SwiftUI
import SafetyWalkCore

/// TBM 안전 브리핑 리포트 (A4) — WO LEGAL-TBM-3 §2.1. Read-only render of a `SafetyBriefing`
/// via the shared `ReportRenderer`. 값 스냅샷(`BriefingRiskItemSnapshot`) 기반 — 원본 평가가
/// 나중에 바뀌거나 지워져도 이 리포트는 브리핑이 소유한 불변 값만 그린다.
///
/// ★ 참석자 이름·서명(제3자 PII)은 포함하지 않는다 — WO LEGAL-2e 에서 오너가 "보류"한 것과 같은 사안
/// (WO LEGAL-TBM-3 §3 기본값). 참석 현황은 인원수·역할·확인방식 **집계**만 싣는다.
@MainActor
enum SafetyBriefingReport {

    private enum RiskCol {
        static let no: CGFloat = 18
        static let task: CGFloat = 110
        static let hazard: CGFloat = 140
        static let controls: CGFloat = 110
        static let risk: CGFloat = 65
    }

    static func pdfURL(for briefing: SafetyBriefing) -> URL? {
        let snapshots = (briefing.riskSnapshots ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SafetyBriefing-\(briefing.id.uuidString).pdf")
        let dateText = (briefing.occurredAt ?? briefing.createdAt).formatted(date: .abbreviated, time: .omitted)
        let subtitle = briefing.siteName.isEmpty ? dateText : "\(briefing.siteName) · \(dateText)"

        var blocks: [AnyView] = [AnyView(headerGrid(briefing))]
        blocks.append(AnyView(contentBlock(briefing)))
        blocks += riskSnapshotBlocks(snapshots)
        blocks.append(AnyView(attendanceSummaryBlock(briefing)))
        blocks.append(AnyView(ReportDisclaimer()))

        return ReportRenderer.renderPDF(
            to: url,
            pageSize: ReportPaper.a4,
            masthead: AnyView(ReportMasthead(title: LocalizationKey.reportBriefingTitle.localized, subtitle: subtitle)),
            footer: { page, total in AnyView(ReportFooter(page: page, total: total)) },
            blocks: blocks
        ) ? url : nil
    }

    // MARK: - 헤더

    private static func headerGrid(_ b: SafetyBriefing) -> some View {
        ReportInfoGrid(pairs: [
            (LocalizationKey.tbmSite.localized, b.siteName.isEmpty ? "—" : b.siteName),
            (LocalizationKey.tbmTaskDescription.localized, b.taskDescription.isEmpty ? "—" : b.taskDescription),
            (LocalizationKey.tbmOccurredAt.localized,
             (b.occurredAt ?? b.createdAt).formatted(date: .abbreviated, time: .shortened)),
            (LocalizationKey.tbmLocation.localized, b.location.isEmpty ? "—" : b.location),
            (LocalizationKey.tbmProfile.localized, b.briefingProfile?.localizedLabel ?? "—"),
            (LocalizationKey.tbmStatus.localized, b.status.localizedLabel),
        ])
    }

    // MARK: - 전달내용

    private static func contentBlock(_ b: SafetyBriefing) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizationKey.tbmContent.localized)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.reportNavy)
            Text(b.briefingContent.isEmpty ? "—" : b.briefingContent)
                .font(.system(size: 8))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 위험 항목 (값 스냅샷)

    /// WO LEGAL-2c 페이지 분할 교훈 재사용: 항목 하나 = 블록 하나. 스냅샷 개수가 평가 항목 수를 넘지
    /// 않는 값 복사본이라 RA 리포트처럼 조치별로 더 쪼개지 않아도 한 블록이 페이지를 넘는 경우는 드물다
    /// — 그래도 넘으면 `ReportRenderer` 가 그 블록만 단독 페이지로 보낸다(잘림 없음, 엔진 자체 동작).
    private static func riskSnapshotBlocks(_ snapshots: [BriefingRiskItemSnapshot]) -> [AnyView] {
        guard !snapshots.isEmpty else {
            return [AnyView(riskSection {
                Text(LocalizationKey.tbmRiskSnapshotsEmpty.localized)
                    .font(.system(size: 8))
                    .foregroundStyle(.black.opacity(0.6))
                    .padding(8)
            })]
        }
        let first = AnyView(riskSection {
            VStack(spacing: 0) {
                riskColumnHeader()
                riskRow(index: 1, snapshots[0], isLast: snapshots.count == 1)
            }
        })
        let rest = snapshots.dropFirst().enumerated().map { offset, snapshot in
            AnyView(riskRow(index: offset + 2, snapshot, isLast: offset == snapshots.count - 2))
        }
        return [first] + rest
    }

    private static func riskSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizationKey.tbmRiskSnapshotsSection.localized)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.reportNavy)
            content()
        }
    }

    private static func riskColumnHeader() -> some View {
        HStack(spacing: 0) {
            head(LocalizationKey.reportNo.localized, RiskCol.no)
            head(LocalizationKey.raItemTask.localized, RiskCol.task)
            head(LocalizationKey.raItemHazard.localized, RiskCol.hazard)
            head(LocalizationKey.raItemCurrentControls.localized, RiskCol.controls)
            head(LocalizationKey.reportJhaRisk.localized, RiskCol.risk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.reportNavy.opacity(0.12))
    }

    private static func riskRow(index: Int, _ snapshot: BriefingRiskItemSnapshot, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 0) {
                cell("\(index)", RiskCol.no)
                cell(snapshot.taskDescription, RiskCol.task)
                cell(snapshot.hazardDescription, RiskCol.hazard)
                cell(snapshot.currentControls, RiskCol.controls)
                riskCell(snapshot)
            }
            controlMeasuresList(snapshot)
                .padding(.leading, RiskCol.no + 3)
                .padding(.bottom, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.black.opacity(isLast ? 0.12 : 0.06)).frame(height: 0.5)
        }
    }

    /// 1:N 개선조치 값 스냅샷 — 문자열로 축약하지 않고 조치별 한 줄씩 나열한다(SCHEMA_V3 §4
    /// "문자열 축약 금지"). 디코딩 실패는 fail-closed로 판독 불가 안내만 보인다(현재 값으로 대체 안 함).
    @ViewBuilder
    private static func controlMeasuresList(_ snapshot: BriefingRiskItemSnapshot) -> some View {
        if let decoded = try? BriefingControlMeasuresSnapshot.decode(
            snapshot.controlMeasuresSnapshot, formatVersion: snapshot.controlMeasuresFormatVersion) {
            if !decoded.measures.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(decoded.measures.enumerated()), id: \.offset) { _, m in
                        Text("· \(m.measure?.isEmpty == false ? m.measure! : LocalizationKey.raNotRecorded.localized)")
                            .font(.system(size: 7))
                            .foregroundStyle(.black.opacity(0.75))
                    }
                }
            }
        } else if snapshot.controlMeasuresSnapshot.isEmpty {
            EmptyView()   // CloudKit 저장속성 기본값(빈 Data) — 조치 없음, 판독 불가 아님
        } else {
            Text(LocalizationKey.raSnapshotUnreadable.localized)
                .font(.system(size: 7))
                .foregroundStyle(.black.opacity(0.6))
        }
    }

    private static func riskCell(_ snapshot: BriefingRiskItemSnapshot) -> some View {
        VStack(spacing: 2) {
            if let level = snapshot.riskLevel {
                ReportRiskBand(level: level)
            } else {
                Text(LocalizationKey.raRiskUnassessed.localized)
                    .font(.system(size: 7)).foregroundStyle(.black.opacity(0.5))
            }
            if let l = snapshot.likelihood, let s = snapshot.severity {
                Text("\(l)×\(s)=\(l * s)")
                    .font(.system(size: 6.5)).monospacedDigit()
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .padding(.horizontal, 2).padding(.vertical, 4)
        .frame(width: RiskCol.risk, alignment: .center)
    }

    // MARK: - 참석 요약 (제3자 PII 제외 — 인원·역할·확인방식 집계만)

    private static func attendanceSummaryBlock(_ b: SafetyBriefing) -> some View {
        let participants = b.participants ?? []
        let byRole = Dictionary(grouping: participants, by: \.role)
        let byConfirmation = Dictionary(grouping: participants.compactMap(\.confirmationMethod), by: { $0 })

        return VStack(alignment: .leading, spacing: 4) {
            Text(LocalizationKey.tbmAttendanceSummaryTitle.localized)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.reportNavy)
            Text(String(format: LocalizationKey.tbmAttendanceSummaryCountFmt.localized, participants.count))
                .font(.system(size: 8))
                .foregroundStyle(.black)
            if !participants.isEmpty {
                HStack(spacing: 14) {
                    ForEach(ParticipantRole.allCases) { role in
                        Text("\(role.localizedLabel) \(byRole[role]?.count ?? 0)")
                            .font(.system(size: 7.5)).foregroundStyle(.black.opacity(0.75))
                    }
                    ForEach(ConfirmationMethod.allCases) { method in
                        Text("\(method.localizedLabel) \(byConfirmation[method]?.count ?? 0)")
                            .font(.system(size: 7.5)).foregroundStyle(.black.opacity(0.75))
                    }
                }
            }
        }
    }

    // MARK: - Cells

    private static func head(_ text: String, _ width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 7.5, weight: .bold))
            .foregroundStyle(Color.reportNavy)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3).padding(.vertical, 4)
            .frame(width: width, alignment: .leading)
    }

    private static func cell(_ string: String, _ width: CGFloat) -> some View {
        Text(string.isEmpty ? "—" : string)
            .font(.system(size: 7.5))
            .foregroundStyle(.black)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 3).padding(.vertical, 4)
            .frame(width: width, alignment: .leading)
    }
}
