import SwiftUI
import SwiftData
import SafetyWalkCore

/// Detail of a TBM Safety Briefing (WO LEGAL-TBM-2 §2.2): lifecycle header, editable
/// 전달내용 while `.draft`, the 위험 스냅샷(read-only, populated by `conduct`), participants
/// (addable through `.conducted`, locked at `.finalized`), and the confirm/cancel actions.
/// Every mutation goes through a `SafetyWalkCore` atomic op — this view never sets a Core
/// field directly (WO LEGAL-TBM-1 §4 "sealed로 Core 우회 불가").
struct SafetyBriefingDetailView: View {
    let briefing: SafetyBriefing

    @Environment(\.modelContext) private var modelContext

    @State private var briefingContentDraft = ""
    @State private var linkedAssessment: RiskAssessment?
    @State private var linkedAssessmentResolved = false
    @State private var showParticipantSheet = false
    @State private var showConductError = false
    @State private var showFinalizeError = false
    @State private var showCancelSheet = false
    @State private var showCancelError = false

    private var participants: [BriefingParticipant] {
        (briefing.participants ?? []).sorted {
            if $0.role != $1.role { return $0.role == .workerRep }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    // BriefingRiskItemSnapshot에는 sortOrder가 없다(값 스냅샷일 뿐 편집 대상 아님) — id로
    // 결정적 정렬한다(CloudKit이 to-many 순서를 보장하지 않는 것과 같은 이유,
    // CorrectiveActionPolicy.sortedCorrectiveActions와 같은 관례).
    private var riskSnapshots: [BriefingRiskItemSnapshot] {
        (briefing.riskSnapshots ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private var canAddParticipant: Bool {
        BriefingParticipantEditing.allowsParticipantEditing(briefing)
    }

    /// linked assessment가 있는데 아직 못 찾았으면(비동기 조회 중이거나, 그 사이 삭제됐으면)
    /// 진행을 막는다 — Core의 `sourceAssessmentRequired` 가드와 같은 조건.
    private var canConduct: Bool {
        !briefingContentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (briefing.assessmentId == nil || linkedAssessment != nil)
    }

    var body: some View {
        List {
            overviewSection
            contentSection
            if briefing.status != .draft {
                riskSnapshotsSection
            }
            participantsSection
            if briefing.status == .conducted {
                finalizeSection
            }
            if briefing.status == .draft || briefing.status == .conducted {
                cancelSection
            }
            if briefing.status == .cancelled {
                cancelledInfoSection
            }
        }
        .navigationTitle(LocalizationKey.tbmTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
        .task { resolveLinkedAssessment() }
        .sheet(isPresented: $showParticipantSheet) {
            BriefingParticipantEditorView(briefing: briefing)
        }
        .sheet(isPresented: $showCancelSheet) {
            BriefingCancelSheet(briefing: briefing, onFailure: { showCancelError = true })
        }
        .alert(LocalizationKey.tbmConductFailedTitle.localized, isPresented: $showConductError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.tbmConductFailedMessage.localized)
        }
        .alert(LocalizationKey.tbmFinalizeFailedTitle.localized, isPresented: $showFinalizeError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.tbmFinalizeFailedMessage.localized)
        }
        .alert(LocalizationKey.tbmCancelFailedTitle.localized, isPresented: $showCancelError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.tbmCancelFailedMessage.localized)
        }
    }

    /// `briefing.assessmentId`는 관계가 아니라 값 UUID(SCHEMA_V3 §5) — 그래서 `@Query` 대신
    /// 일회성 fetch로 해석한다. 이 화면은 Home→목록→상세로 depth-2에 밀리는데, depth-2+ 에서
    /// `@Query(filter: #Predicate)`를 프로퍼티로 선언하면 push 시점에 앱이 멈춘 전례가 있다
    /// (/navigation-qa). `.task` 안의 일회성 `modelContext.fetch`는 push 가 끝난 뒤 비동기로
    /// 실행되므로 그 문제를 겪지 않는다.
    private func resolveLinkedAssessment() {
        defer { linkedAssessmentResolved = true }
        guard let targetId = briefing.assessmentId else { return }
        let descriptor = FetchDescriptor<RiskAssessment>(
            predicate: #Predicate<RiskAssessment> { $0.id == targetId })
        linkedAssessment = try? modelContext.fetch(descriptor).first
    }

    // MARK: - Overview

    private var overviewSection: some View {
        Section {
            HStack {
                Text(LocalizationKey.tbmStatus.localized).foregroundStyle(.secondary)
                Spacer()
                BriefingStatusBadge(status: briefing.status)
            }
            .font(.subheadline)

            infoRow(LocalizationKey.tbmSite.localized,
                    briefing.siteName.isEmpty ? LocalizationKey.tbmSiteNone.localized : briefing.siteName)
            if !briefing.taskDescription.isEmpty {
                infoRow(LocalizationKey.tbmTaskDescription.localized, briefing.taskDescription)
            }
            if let occurredAt = briefing.occurredAt {
                infoRow(LocalizationKey.tbmOccurredAt.localized,
                        occurredAt.formatted(date: .abbreviated, time: .shortened))
            }
            if !briefing.location.isEmpty {
                infoRow(LocalizationKey.tbmLocation.localized, briefing.location)
            }
            if let profile = briefing.briefingProfile {
                infoRow(LocalizationKey.tbmProfile.localized, profile.localizedLabel)
            }
            linkedAssessmentRow
        }
    }

    @ViewBuilder
    private var linkedAssessmentRow: some View {
        if briefing.assessmentId != nil {
            infoRow(LocalizationKey.tbmLinkedAssessment.localized,
                    linkedAssessment.map { $0.siteName.isEmpty ? $0.method.localizedLabel
                                                                : "\($0.siteName) · \($0.method.localizedLabel)" }
                        ?? "—")
        }
    }

    // MARK: - 전달내용 (locked at conducted — TBM_0_ARCH §5)

    @ViewBuilder
    private var contentSection: some View {
        if briefing.status == .draft {
            Section(LocalizationKey.tbmContent.localized) {
                TextEditor(text: $briefingContentDraft)
                    .frame(minHeight: 100)
                    .accessibilityIdentifier("tbm_content_editor")
                Button {
                    conduct()
                } label: {
                    Label(LocalizationKey.tbmConduct.localized, systemImage: "play.circle.fill")
                        .font(.headline)
                }
                .frame(minHeight: 44)
                .disabled(!canConduct)
                .accessibilityIdentifier("tbm_conduct")

                if briefing.assessmentId != nil, linkedAssessmentResolved, linkedAssessment == nil {
                    Text(LocalizationKey.tbmLinkedAssessmentMissing.localized)
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(LocalizationKey.tbmConductHint.localized)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } else if !briefing.briefingContent.isEmpty {
            Section(LocalizationKey.tbmContent.localized) {
                Text(briefing.briefingContent)
                Text(LocalizationKey.tbmContentLockedHint.localized)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func conduct() {
        do {
            try BriefingLifecycle.conduct(briefing, briefingContent: briefingContentDraft,
                                          sourceAssessment: linkedAssessment, now: Date(), in: modelContext)
        } catch {
            showConductError = true
        }
    }

    // MARK: - 위험 스냅샷 (conduct 시 값 복사, 이후 불변)

    private var riskSnapshotsSection: some View {
        Section(LocalizationKey.tbmRiskSnapshotsSection.localized) {
            if riskSnapshots.isEmpty {
                Text(LocalizationKey.tbmRiskSnapshotsEmpty.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(riskSnapshots) { snapshot in
                    BriefingRiskSnapshotRow(snapshot: snapshot)
                }
            }
        }
    }

    // MARK: - 참석자 (conducted 까지 추가 가능, finalized 후 잠금)

    private var participantsSection: some View {
        Section(LocalizationKey.tbmParticipants.localized) {
            if participants.isEmpty {
                Text(LocalizationKey.tbmParticipantsEmpty.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(participants) { p in
                    BriefingParticipantRow(participant: p)
                }
            }

            if canAddParticipant {
                Button { showParticipantSheet = true } label: {
                    Label(LocalizationKey.tbmParticipantAdd.localized, systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("tbm_add_participant")
            } else if briefing.status == .finalized {
                Text(LocalizationKey.tbmParticipantsLockedHint.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 확정 (conducted → finalized)

    private var finalizeSection: some View {
        Section {
            Button {
                finalize()
            } label: {
                Label(LocalizationKey.tbmFinalize.localized, systemImage: "lock.circle.fill")
                    .font(.headline)
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("tbm_finalize")

            Text(LocalizationKey.tbmFinalizeHint.localized)
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func finalize() {
        do {
            try BriefingLifecycle.finalize(briefing, now: Date(), in: modelContext)
        } catch {
            showFinalizeError = true
        }
    }

    // MARK: - 취소 (draft/conducted → cancelled)

    private var cancelSection: some View {
        Section {
            Button(role: .destructive) {
                showCancelSheet = true
            } label: {
                Label(LocalizationKey.tbmCancel.localized, systemImage: "xmark.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("tbm_cancel")
        }
    }

    private var cancelledInfoSection: some View {
        Section {
            infoRow(LocalizationKey.tbmStatus.localized, LocalizationKey.tbmStatusCancelled.localized)
            if let reason = briefing.cancellationReason, !reason.isEmpty {
                infoRow(LocalizationKey.tbmCancellationReason.localized, reason)
            }
            if let at = briefing.cancelledAt {
                infoRow(LocalizationKey.commonDone.localized, at.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

}

// MARK: - Row views

private struct BriefingRiskSnapshotRow: View {
    let snapshot: BriefingRiskItemSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    if !snapshot.taskDescription.isEmpty {
                        Text(snapshot.taskDescription)
                            .font(.subheadline.weight(.semibold))
                    }
                    if !snapshot.hazardDescription.isEmpty {
                        Text(snapshot.hazardDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let level = snapshot.riskLevel {
                    RiskChip(level: level)
                } else {
                    Text(LocalizationKey.raRiskUnassessed.localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct BriefingParticipantRow: View {
    let participant: BriefingParticipant

    var body: some View {
        HStack(spacing: 8) {
            Text(participant.name.isEmpty ? "—" : participant.name)
                .font(.subheadline.weight(.semibold))
            Text(participant.role.localizedLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(participant.role == .workerRep ? Color.blue : Color.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill((participant.role == .workerRep ? Color.blue : Color.secondary).opacity(0.12)))
            if let confirm = participant.confirmationMethod {
                Text(confirm.localizedLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if participant.signatureData != nil {
                Label(LocalizationKey.raSignatureCaptured.localized, systemImage: "signature")
                    .labelStyle(.iconOnly)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(LocalizationKey.raSignatureCaptured.localized)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Cancel sheet

/// 취소 사유 입력 — `BriefingLifecycle.cancel` 은 비공백 사유를 요구한다(§2.2). 작은 전용 시트로
/// 분리해 상세 화면의 alert 하나로 텍스트 입력까지 욱여넣지 않는다.
private struct BriefingCancelSheet: View {
    let briefing: SafetyBriefing
    let onFailure: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var reason = ""

    private var canCancel: Bool {
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizationKey.tbmCancelTitle.localized) {
                    TextField(LocalizationKey.tbmCancelReasonPlaceholder.localized, text: $reason)
                        .accessibilityIdentifier("tbm_cancel_reason")
                }
            }
            .navigationTitle(LocalizationKey.tbmCancel.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonConfirm.localized) { cancel() }
                        .disabled(!canCancel)
                        .accessibilityIdentifier("tbm_cancel_confirm")
                }
            }
        }
    }

    private func cancel() {
        do {
            try BriefingLifecycle.cancel(briefing, reason: reason, now: Date(), in: modelContext)
            dismiss()
        } catch {
            dismiss()
            onFailure()
        }
    }
}
