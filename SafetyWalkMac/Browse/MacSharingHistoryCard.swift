import SwiftUI
import SwiftData
import SafetyWalkCore

/// 통합 공유 이력 + 공유 당시 내용 — **조회 전용** (WO LEGAL-2d §6 + WO LEGAL-TBM-3 §2).
/// `UnifiedSharingHistory`(SafetyWalkCore)를 통해 TBM 공유(확정된 `SafetyBriefing`) + 비TBM 공유
/// (`SharingEvent`)를 하나의 시간순 이력으로 보여준다(TBM_0_ARCH §8 "이중 저장 제거" — TBM 은 별도
/// SharingEvent 를 만들지 않으므로 이 카드가 유일한 합류 지점이다). macOS 는 매니저 대시보드/리포트
/// 허브이고 현재 정책은 read-only 이므로, iOS 의 공유 기록 생성·평가 확정·브리핑 진행/확정 기능을
/// 여기서 복제하지 않는다. 행을 펼치면 그 시점의 불변 스냅샷/전달내용을 보여주고, decode 실패는
/// fail-closed 오류로 표시한다.
struct MacSharingHistoryCard: View {
    let assessment: RiskAssessment
    @Environment(\.modelContext) private var modelContext

    private var entries: [UnifiedSharingHistoryEntry] {
        UnifiedSharingHistory.entries(for: assessment, in: modelContext)
    }

    var body: some View {
        MacCard(title: LocalizationKey.raSharingSection.localized, systemImage: "square.and.arrow.up") {
            VStack(alignment: .leading, spacing: 8) {
                if SharingEventPolicy.jurisdictionState(assessment) == .unset {
                    Text(LocalizationKey.raSharingJurisdictionUnsetHint.localized)
                        .font(.caption)
                        .foregroundStyle(Color.macMuted)
                }

                if entries.isEmpty {
                    Text(LocalizationKey.raSharingEmpty.localized)
                        .font(.callout)
                        .foregroundStyle(Color.macMuted)
                } else {
                    ForEach(entries) { entry in
                        row(for: entry)
                        if entry.id != entries.last?.id { Divider() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for entry: UnifiedSharingHistoryEntry) -> some View {
        switch entry {
        case .sharingEvent(let event):
            MacSharingEventRow(event: event, isStale: SharingEventPolicy.isStale(event, in: assessment))
        case .briefing(let briefing):
            MacBriefingHistoryRow(briefing: briefing)
        }
    }
}

/// TBM 공유 항목 한 건 — 확정된 브리핑 자체가 공유 증명이므로(TBM_0_ARCH §8) SharingEvent 행과 같은
/// 자리에서 같은 형태로 보인다. 참석자 이름은 조회 전용 화면이라도 여기서는 보여주지 않는다 — 이
/// 카드는 "평가의 공유 이력 증명"이 목적이라 참석자 세부는 브리핑 자체의 조회 화면
/// (`SafetyBriefingsBrowseView`) 몫으로 남긴다(범위 최소화, WO LEGAL-TBM-3).
private struct MacBriefingHistoryRow: View {
    let briefing: SafetyBriefing

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(LocalizationKey.tbmUnifiedHistoryTbmLabel.localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandNavy)
                if !briefing.taskDescription.isEmpty {
                    Text(briefing.taskDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let at = briefing.finalizedAt {
                    Text(at.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            Text(String(format: LocalizationKey.tbmAttendanceSummaryCountFmt.localized,
                        (briefing.participants ?? []).count))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct MacSharingEventRow: View {
    let event: SharingEvent
    let isStale: Bool

    var body: some View {
        DisclosureGroup {
            snapshotBody
                .padding(.top, 4)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    if let phase = event.phase {
                        Text(phase.localizedLabel).font(.caption.weight(.semibold))
                    }
                    if let method = event.method {
                        Text(method.localizedLabel).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if let at = event.sharedAt {
                        Text(at.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 10) {
                    Text("\(LocalizationKey.raSharingTarget.localized) \(event.target ?? "—")")
                    Text("\(LocalizationKey.raSharingOwner.localized) \(event.ownerName ?? "—")")
                }
                .font(.caption2).foregroundStyle(.secondary)
                if isStale {
                    Text(LocalizationKey.raSharingStale.localized)
                        .font(.caption2).foregroundStyle(Color.macMuted)
                }
            }
        }
    }

    /// 저장된 스냅샷만 렌더링한다 — 평가의 현재 값으로 대체하지 않는다.
    @ViewBuilder
    private var snapshotBody: some View {
        if let snapshot = try? SharingEventPolicy.decodeSnapshot(event) {
            VStack(alignment: .leading, spacing: 4) {
                if snapshot.phase == SharingPhase.pre.rawValue {
                    if let scheduled = snapshot.scheduledAt {
                        DetailField(label: LocalizationKey.raSnapshotSchedule.localized,
                                    value: scheduled.formatted(date: .abbreviated, time: .omitted))
                    }
                } else if snapshot.items.isEmpty {
                    Text(LocalizationKey.raSnapshotNoItems.localized)
                        .font(.caption).foregroundStyle(Color.macMuted)
                } else {
                    ForEach(snapshot.items, id: \.itemId) { item in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.taskDescription).font(.caption.weight(.medium))
                            Text(item.hazardDescription).font(.caption2).foregroundStyle(.secondary)
                            ForEach(item.correctiveActions, id: \.actionId) { action in
                                Text("· \(action.measure ?? "—")")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizationKey.raSnapshotUnreadable.localized)
                    .font(.caption.weight(.semibold))
                Text(LocalizationKey.raSnapshotUnreadableHint.localized)
                    .font(.caption2).foregroundStyle(Color.macMuted)
            }
        }
    }
}
