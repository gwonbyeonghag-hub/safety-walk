import SwiftUI
import SafetyWalkCore

/// 공유 이력 섹션 (WO LEGAL-2d §6) — 모든 평가 상태에서 시간 역순으로 표시된다. 각 행은 사전/사후·방법·
/// 시각·대상·담당자를 보여주고, 선택하면 그 시점의 **불변 스냅샷** 상세로 들어간다.
///
/// 현재 내용과 달라진 기록에는 "현재 내용과 다름" 배지를 단다 — 삭제가 아니라 사실 표시다. 배지 문구는
/// 위반/미준수가 아니라 **차이**만 말한다(CLAUDE.md No legal judgment).
struct SharingHistorySection: View {
    let assessment: RiskAssessment

    private var events: [SharingEvent] { SharingEventPolicy.sortedEvents(assessment) }

    var body: some View {
        Section(LocalizationKey.raSharingSection.localized) {
            // 관할 미설정이면 어떤 법규 충족도 주장하지 않는다는 사실을 먼저 알린다.
            if SharingEventPolicy.jurisdictionState(assessment) == .unset {
                jurisdictionUnsetNotice
            }

            if events.isEmpty {
                Text(LocalizationKey.raSharingEmpty.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("ra_sharing_empty")
            } else {
                ForEach(events) { event in
                    NavigationLink {
                        SharingSnapshotDetailView(event: event)
                    } label: {
                        SharingEventRow(event: event,
                                        isStale: SharingEventPolicy.isStale(event, in: assessment))
                    }
                    .accessibilityIdentifier("ra_sharing_history_row")
                }
            }
        }
    }

    private var jurisdictionUnsetNotice: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(LocalizationKey.raSharingJurisdictionUnset.localized, systemImage: "questionmark.circle")
                .font(.caption.weight(.semibold))
            Text(LocalizationKey.raSharingJurisdictionUnsetHint.localized)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("ra_sharing_jurisdiction_unset")
    }
}

/// 한 건의 공유 기록: 사전/사후 · 방법 · 시각 · 대상 · 담당자.
struct SharingEventRow: View {
    let event: SharingEvent
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let phase = event.phase { SharingPhasePill(phase: phase) }
                if let method = event.method {
                    Label(method.localizedLabel, systemImage: method.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if let at = event.sharedAt {
                    Text(at.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                metaLine(LocalizationKey.raSharingTarget.localized, event.target ?? "—")
                metaLine(LocalizationKey.raSharingOwner.localized, event.ownerName ?? "—")
            }
            if isStale {
                Label(LocalizationKey.raSharingStale.localized, systemImage: "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("ra_sharing_stale_badge")
            }
        }
        .padding(.vertical, 2)
    }

    private func metaLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption2)
        }
    }
}
