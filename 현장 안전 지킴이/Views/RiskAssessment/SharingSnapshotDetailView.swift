import SwiftUI
import SafetyWalkCore

/// 공유 당시 내용 상세 (WO LEGAL-2d §6). 저장된 **불변 스냅샷만** 렌더링한다 — 평가의 현재 값은 절대
/// 읽지 않는다. decode 에 실패하면 현재 데이터로 대체하지 않고 fail-closed 오류 상태를 표시한다
/// (SCHEMA_V3 §7: 손상 스냅샷은 조용히 진행 금지).
struct SharingSnapshotDetailView: View {
    let event: SharingEvent

    var body: some View {
        List {
            switch decoded {
            case .success(let snapshot):
                headerSection(snapshot)
                if snapshot.phase == SharingPhase.pre.rawValue {
                    scheduleSection(snapshot)
                } else {
                    itemsSection(snapshot)
                }
            case .failure:
                unreadableSection
            }
        }
        .navigationTitle(LocalizationKey.raSnapshotTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var decoded: Result<SharingSnapshot, Error> {
        Result { try SharingEventPolicy.decodeSnapshot(event) }
    }

    // MARK: - 공유 사실 (이벤트 자체)

    private func headerSection(_ snapshot: SharingSnapshot) -> some View {
        Section(LocalizationKey.raSnapshotContext.localized) {
            if let phase = event.phase {
                row(LocalizationKey.raSharingSection.localized, phase.localizedLabel)
            }
            if let method = event.method {
                row(LocalizationKey.raSharingMethod.localized, method.localizedLabel)
            }
            if let at = event.sharedAt {
                row(LocalizationKey.raSharingSharedAt.localized,
                    at.formatted(date: .abbreviated, time: .shortened))
            }
            row(LocalizationKey.raSharingTarget.localized, event.target ?? "—")
            row(LocalizationKey.raSharingOwner.localized, event.ownerName ?? "—")
            row(LocalizationKey.raSite.localized, snapshot.siteName)
        }
    }

    // MARK: - 사전: 공유된 일정

    @ViewBuilder
    private func scheduleSection(_ snapshot: SharingSnapshot) -> some View {
        Section(LocalizationKey.raSnapshotSchedule.localized) {
            if let scheduled = snapshot.scheduledAt {
                row(LocalizationKey.raSchedule.localized,
                    scheduled.formatted(date: .abbreviated, time: .omitted))
            } else {
                Text(LocalizationKey.raNotRecorded.localized)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 사후: 유해위험요인·결정 + 1:N 개선조치

    @ViewBuilder
    private func itemsSection(_ snapshot: SharingSnapshot) -> some View {
        if snapshot.items.isEmpty {
            Section(LocalizationKey.raSnapshotItems.localized) {
                Text(LocalizationKey.raSnapshotNoItems.localized)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        } else {
            ForEach(snapshot.items, id: \.itemId) { item in
                Section(header: Text(item.taskDescription.isEmpty
                                     ? LocalizationKey.raSnapshotItems.localized
                                     : item.taskDescription)) {
                    if !item.hazardDescription.isEmpty {
                        row(LocalizationKey.raItemHazard.localized, item.hazardDescription)
                    }
                    if let controls = item.currentControls, !controls.isEmpty {
                        row(LocalizationKey.raItemCurrentControls.localized, controls)
                    }
                    row(LocalizationKey.raItemRiskLevel.localized, riskText(item.riskLevel))
                    if let l = item.likelihood, let s = item.severity {
                        row(LocalizationKey.raItemScore.localized, "\(l) × \(s) = \(l * s)")
                    }
                    row(LocalizationKey.raDecisionConfirm.localized, decisionText(item.criteriaDecision))
                    actionsView(item.correctiveActions)
                }
            }
        }
    }

    @ViewBuilder
    private func actionsView(_ actions: [SharingSnapshot.Action]) -> some View {
        if actions.isEmpty {
            Text(LocalizationKey.raSnapshotNoActions.localized)
                .font(.caption).foregroundStyle(.secondary)
        } else {
            ForEach(actions, id: \.actionId) { action in
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.measure ?? "—").font(.subheadline.weight(.semibold))
                    metaLine(LocalizationKey.raItemStatus.localized, statusText(action.status))
                    if let who = action.responsibleName, !who.isEmpty {
                        metaLine(LocalizationKey.raItemResponsible.localized, who)
                    }
                    if let due = action.dueDate {
                        metaLine(LocalizationKey.raItemDueDate.localized,
                                 due.formatted(date: .abbreviated, time: .omitted))
                    }
                    if let done = action.implementedAt {
                        metaLine(LocalizationKey.raActionImplementedAt.localized,
                                 done.formatted(date: .abbreviated, time: .omitted))
                    }
                    if let post = action.postRiskLevel {
                        metaLine(LocalizationKey.raItemPostRiskLevel.localized, riskText(post))
                    }
                    if let result = action.effectivenessResult {
                        metaLine(LocalizationKey.raActionEffResult.localized, effectivenessText(result))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - fail-closed

    private var unreadableSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label(LocalizationKey.raSnapshotUnreadable.localized,
                      systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                Text(LocalizationKey.raSnapshotUnreadableHint.localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .accessibilityIdentifier("ra_snapshot_unreadable")
        }
    }

    // MARK: - Raw-code → localized label
    // 스냅샷은 안정 raw code 를 저장한다(교정 #6). 알 수 없는 코드는 지어내지 않고 미기록으로 표시한다.

    private func riskText(_ raw: String?) -> String {
        guard let raw, let level = RiskLevel(rawValue: raw) else {
            return LocalizationKey.raRiskUnassessed.localized
        }
        return level.localizedLabel
    }

    private func decisionText(_ raw: String?) -> String {
        guard let raw, let decision = CriteriaDecision(rawValue: raw) else {
            return LocalizationKey.raRiskUnassessed.localized
        }
        return decision.localizedLabel
    }

    private func statusText(_ raw: String) -> String {
        CorrectiveActionStatus(rawValue: raw)?.localizedLabel ?? LocalizationKey.raNotRecorded.localized
    }

    private func effectivenessText(_ raw: String) -> String {
        EffectivenessResult(rawValue: raw)?.localizedLabel ?? LocalizationKey.raNotRecorded.localized
    }

    // MARK: - Rows

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func metaLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption2)
        }
    }
}
