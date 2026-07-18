import SwiftUI
import SafetyWalkCore

/// 공유 이력 + 공유 당시 내용 — **조회 전용** (WO LEGAL-2d §6). macOS 는 매니저 대시보드/리포트 허브이고
/// 현재 위험성평가 정책은 read-only 이므로, iOS 의 공유 기록 생성·평가 확정 기능을 여기서 복제하지 않는다.
/// 행을 펼치면 그 시점의 불변 스냅샷을 보여주고, decode 실패는 fail-closed 오류로 표시한다.
struct MacSharingHistoryCard: View {
    let assessment: RiskAssessment

    private var events: [SharingEvent] { SharingEventPolicy.sortedEvents(assessment) }

    var body: some View {
        MacCard(title: LocalizationKey.raSharingSection.localized, systemImage: "square.and.arrow.up") {
            VStack(alignment: .leading, spacing: 8) {
                if SharingEventPolicy.jurisdictionState(assessment) == .unset {
                    Text(LocalizationKey.raSharingJurisdictionUnsetHint.localized)
                        .font(.caption)
                        .foregroundStyle(Color.macMuted)
                }

                if events.isEmpty {
                    Text(LocalizationKey.raSharingEmpty.localized)
                        .font(.callout)
                        .foregroundStyle(Color.macMuted)
                } else {
                    ForEach(events) { event in
                        MacSharingEventRow(event: event,
                                           isStale: SharingEventPolicy.isStale(event, in: assessment))
                        if event.id != events.last?.id { Divider() }
                    }
                }
            }
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
