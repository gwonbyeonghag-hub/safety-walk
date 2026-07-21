import SwiftUI
import SwiftData
import SafetyWalkCore

/// TBM 안전 브리핑 조회 — **읽기 전용** (WO LEGAL-TBM-3 §2.3). macOS 는 매니저 대시보드/리포트
/// 허브이고 브리핑 생성·진행·확정은 iOS 현장 도구가 담당하므로(CLAUDE.md), 여기서는 생성·conduct·
/// finalize 버튼을 두지 않는다 — 목록+상세 조회만.
struct SafetyBriefingsBrowseView: View {
    @Query private var briefings: [SafetyBriefing]
    @Environment(\.modelContext) private var modelContext

    private var sorted: [SafetyBriefing] {
        briefings.sorted { ($0.occurredAt ?? $0.createdAt) > ($1.occurredAt ?? $1.createdAt) }
    }

    var body: some View {
        BrowseLayout(items: sorted) { b in
            VStack(alignment: .leading, spacing: 2) {
                Text(b.taskDescription.isEmpty ? b.siteName : b.taskDescription).font(.body).lineLimit(1)
                HStack(spacing: 6) {
                    Text(b.siteName)
                    Text("·")
                    Text((b.occurredAt ?? b.createdAt).formatted(date: .abbreviated, time: .omitted)).monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        } detail: { b in
            detail(b)
        }
        .navigationTitle(LocalizationKey.macSectionBriefings.localized)
    }

    @ViewBuilder
    private func detail(_ b: SafetyBriefing) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailHeader(title: b.taskDescription.isEmpty ? b.siteName : b.taskDescription,
                         subtitle: "\(b.siteName) · \(b.status.localizedLabel)")

            MacCard {
                VStack(spacing: 6) {
                    DetailField(label: LocalizationKey.tbmSite.localized, value: b.siteName)
                    DetailField(label: LocalizationKey.tbmOccurredAt.localized,
                                value: (b.occurredAt ?? b.createdAt).formatted(date: .abbreviated, time: .shortened))
                    DetailField(label: LocalizationKey.tbmLocation.localized, value: b.location)
                    DetailField(label: LocalizationKey.tbmProfile.localized, value: b.briefingProfile?.localizedLabel ?? "—")
                    DetailField(label: LocalizationKey.tbmStatus.localized, value: b.status.localizedLabel)
                    if b.assessmentId != nil {
                        DetailField(label: LocalizationKey.tbmLinkedAssessment.localized, value: linkedAssessmentLabel(b))
                    }
                }
            }

            if !b.briefingContent.isEmpty {
                MacCard(title: LocalizationKey.tbmContent.localized, systemImage: "text.alignleft") {
                    Text(b.briefingContent).font(.callout).foregroundStyle(Color.macInk)
                }
            }

            riskSnapshotsCard(b)

            // 참석자 — 조회 전용 화면(내보내기 대상 아님)이라 이름을 그대로 보여준다. 내보내는
            // 리포트(SafetyBriefingReport, ReportHubView)는 제3자 PII를 뺀 집계만 싣는다
            // (WO LEGAL-TBM-3 §3 — 2e 결정과 일관, 익스포트 아티팩트에만 적용).
            participantsCard(b)

            ReportDisclaimerInline()
        }
    }

    /// `assessmentId`는 관계가 아니라 값 UUID(SCHEMA_V3 §5) — 한 번만 조회해 표시용 라벨만 만든다.
    /// 목록 규모가 작은 매니저 조회 화면이라 행마다 즉시 fetch 해도 무리 없다(대량 리스트 아님).
    private func linkedAssessmentLabel(_ b: SafetyBriefing) -> String {
        guard let targetId = b.assessmentId else { return "—" }
        let descriptor = FetchDescriptor<RiskAssessment>(
            predicate: #Predicate<RiskAssessment> { $0.id == targetId })
        guard let ra = try? modelContext.fetch(descriptor).first else { return "—" }
        return ra.siteName.isEmpty ? ra.method.localizedLabel : "\(ra.siteName) · \(ra.method.localizedLabel)"
    }

    private func riskSnapshotsCard(_ b: SafetyBriefing) -> some View {
        let snapshots = (b.riskSnapshots ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
        return MacCard(title: LocalizationKey.tbmRiskSnapshotsSection.localized, systemImage: "tablecells") {
            if snapshots.isEmpty {
                Text(LocalizationKey.tbmRiskSnapshotsEmpty.localized)
                    .font(.callout).foregroundStyle(Color.macMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(snapshots.enumerated()), id: \.element.id) { idx, snap in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(idx + 1)").font(.callout.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(Color.brandNavy).frame(width: 22, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snap.taskDescription).font(.callout.weight(.medium))
                                Text(snap.hazardDescription).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 2) {
                                if let level = snap.riskLevel {
                                    RiskChip(level: level)
                                } else {
                                    Text(LocalizationKey.raRiskUnassessed.localized)
                                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                }
                                if let l = snap.likelihood, let s = snap.severity {
                                    Text("\(l)×\(s)=\(l * s)").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                                }
                            }
                        }
                        if snap.id != snapshots.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func participantsCard(_ b: SafetyBriefing) -> some View {
        let participants = (b.participants ?? []).sorted {
            if $0.role != $1.role { return $0.role == .workerRep }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
        return MacCard(title: LocalizationKey.tbmParticipants.localized, systemImage: "person.2") {
            if participants.isEmpty {
                Text(LocalizationKey.tbmParticipantsEmpty.localized)
                    .font(.callout).foregroundStyle(Color.macMuted)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(participants) { p in
                        HStack(spacing: 8) {
                            Text(p.name).font(.callout.weight(.medium))
                            Text(p.role.localizedLabel).font(.caption).foregroundStyle(.secondary)
                            if let confirm = p.confirmationMethod {
                                Text(confirm.localizedLabel).font(.caption2).foregroundStyle(Color.macMuted)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}
