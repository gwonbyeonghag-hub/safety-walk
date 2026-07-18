import SwiftUI
import SwiftData
import SafetyWalkCore

/// Detail of a 위험성평가: lifecycle header (status · schedule), the 2a management
/// sections (근로자 대표 · 참여자), each item with its resolved risk band, and the
/// non-removable disclaimer (앱은 기록만, 판정 안 함). Worker-rep and participants are
/// editable while the assessment is planned/inProgress; once finalized/cancelled they
/// are read-only (SCHEMA_V3 §7 잠금).
struct RiskAssessmentDetailView: View {
    let assessment: RiskAssessment

    @Environment(\.modelContext) private var modelContext
    @State private var participantSheet: ParticipantSheet?
    @State private var showStartSheet = false
    @State private var showSaveError = false
    /// 공유 기록 시트의 시점 — 진입점(planned=사전 / finalized=사후)이 정하며 시트 안에서 바꿀 수 없다.
    @State private var sharingSheetPhase: SharingPhase?
    @State private var showFinalizeError = false
    @State private var finalizeErrorMessage = LocalizationKey.raFinalizeFailedMessage.localized

    // Sorted by sortOrder so JSA work steps display in their entered order
    // (CloudKit does not preserve to-many relationship order).
    private var items: [RiskAssessmentItem] {
        (assessment.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    // Worker-rep first, then by name — CloudKit doesn't preserve to-many order.
    private var participants: [RiskAssessmentParticipant] {
        (assessment.participants ?? []).sorted {
            if $0.role != $1.role { return $0.role == .workerRep }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    /// Finalized/cancelled records lock their participants + worker-rep (§7).
    private var isLocked: Bool {
        assessment.status == .finalized || assessment.status == .cancelled
    }

    /// The locked criteria, decoded once for the whole screen (nil = no criteria yet, or a
    /// fail-closed decode). The 기준 이내/초과 SUGGESTION is derived from this — never re-computed
    /// in a view (WO LEGAL-2b §5).
    private var decodedCriteria: AcceptabilityCriteria? {
        guard let c = assessment.criteria else { return nil }
        return try? AcceptabilityCriteria.decode(
            from: c, usesFrequencySeverity: assessment.method.usesFrequencySeverity)
    }

    var body: some View {
        List {
            overviewSection
            if assessment.status == .planned { startSection }
            // Once started the criteria is locked — show it read-only above the items it governs.
            if assessment.status != .planned, let criteria = assessment.criteria {
                LockedCriteriaSection(criteria: criteria,
                                      usesFrequencySeverity: assessment.method.usesFrequencySeverity)
            }
            // Items stay directly under the header (the risk content); the 2a participation
            // sections follow so a conducted assessment reads content-first.
            itemsSection
            // WO LEGAL-2d: 확정은 항목 바로 아래 — 항목 내용을 확인한 뒤 잠그는 순서로 읽히고,
            // planned 의 "평가 시작"과 같은 위치(주 생명주기 동작)에 놓인다.
            if assessment.status == .inProgress { finalizeSection }
            workerRepSection
            participantsSection
            // 공유는 "무엇을 했는지"의 기록 — 내용·참여 다음, 면책 고지 앞에 온다.
            sharingActionSection
            SharingHistorySection(assessment: assessment)
            Section {
                DisclaimerView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(LocalizationKey.raTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $participantSheet) { sheet in
            ParticipantEditorView(assessment: assessment, existing: sheet.participant)
        }
        .sheet(isPresented: $showStartSheet) {
            AssessmentStartSheet(assessment: assessment)
        }
        .sheet(item: $sharingSheetPhase) { phase in
            SharingRecordView(assessment: assessment, phase: phase)
        }
        .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $showSaveError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.raSaveFailedMessage.localized)
        }
        .alert(LocalizationKey.raFinalizeFailedTitle.localized, isPresented: $showFinalizeError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(finalizeErrorMessage)
        }
    }

    // MARK: - 공유 기록 (WO LEGAL-2d) — 진입점이 시점을 결정한다

    /// planned → 사전(일정) 공유, finalized → 사후(결과) 공유. inProgress/cancelled 에는 생성 진입점이
    /// 없다 — Core 도 같은 규칙으로 거부하므로 화면과 규칙이 어긋나지 않는다.
    @ViewBuilder
    private var sharingActionSection: some View {
        switch assessment.status {
        case .planned:
            Section {
                Button { sharingSheetPhase = .pre } label: {
                    Label(LocalizationKey.raSharingRecordPre.localized, systemImage: "calendar.badge.plus")
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("ra_record_pre_sharing")

                // KR 관할에서 사전 공유가 시작의 전제라는 사실 안내 (판정 문구 아님 — 필요 조건 안내).
                if SharingEventPolicy.requiresPreSharingGate(assessment),
                   !SharingEventPolicy.satisfiesPreSharingGate(assessment) {
                    Text(LocalizationKey.raSharingPreGateRequired.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("ra_pre_sharing_required_hint")
                }
            }
        case .finalized:
            Section {
                Button { sharingSheetPhase = .post } label: {
                    Label(LocalizationKey.raSharingRecordPost.localized, systemImage: "square.and.arrow.up")
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("ra_record_post_sharing")
            }
        case .inProgress, .cancelled:
            EmptyView()
        }
    }

    // MARK: - 평가 확정 (inProgress → finalized)

    private var finalizeSection: some View {
        Section {
            Button {
                finalize()
            } label: {
                Label(LocalizationKey.raFinalizeAction.localized, systemImage: "lock.circle.fill")
                    .font(.headline)
            }
            .frame(minHeight: 44)
            .disabled(!AssessmentFinalization.isReadyToFinalize(assessment))
            .accessibilityIdentifier("ra_finalize_assessment")

            // 왜 아직 확정할 수 없는지 — 준비 미충족과 KR 사전공유 미충족을 구분해 알린다.
            if !AssessmentFinalization.isReadyToFinalize(assessment) {
                Text(LocalizationKey.raFinalizeNotReady.localized)
                    .font(.caption).foregroundStyle(.secondary)
            } else if !SharingEventPolicy.satisfiesPreSharingGate(assessment) {
                Text(LocalizationKey.raFinalizePreSharingRequired.localized)
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("ra_finalize_pre_sharing_hint")
            } else {
                Text(LocalizationKey.raFinalizeHint.localized)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// 확정은 원자적 Core op 하나로 — readiness·KR 사전공유를 그 안에서 다시 검증하고, 실패하면 상태와
    /// 시각을 store·메모리 양쪽에서 되돌린다. View 는 로컬라이즈된 알럿만 띄운다(성공 시에만 상태 변경).
    private func finalize() {
        do {
            try AssessmentFinalization.finalize(assessment, now: Date(), in: modelContext)
        } catch AssessmentFinalizeError.missingCurrentPreSharing {
            finalizeErrorMessage = LocalizationKey.raFinalizePreSharingRequired.localized
            showFinalizeError = true
        } catch AssessmentFinalizeError.notReady {
            finalizeErrorMessage = LocalizationKey.raFinalizeNotReady.localized
            showFinalizeError = true
        } catch {
            finalizeErrorMessage = LocalizationKey.raFinalizeFailedMessage.localized
            showFinalizeError = true
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        Section {
            HStack {
                Text(LocalizationKey.raStatus.localized).foregroundStyle(.secondary)
                Spacer()
                AssessmentStatusBadge(status: assessment.status)
            }
            .font(.subheadline)

            infoRow(LocalizationKey.raKind.localized, assessment.kind.localizedLabel)
            infoRow(LocalizationKey.raMethod.localized, assessment.method.localizedLabel)
            infoRow(LocalizationKey.raSite.localized,
                    assessment.siteName.isEmpty ? LocalizationKey.raSiteNone.localized : assessment.siteName)
            infoRow(LocalizationKey.raAssessor.localized, assessment.assessorName)

            if assessment.status == .planned, let scheduled = assessment.scheduledAt {
                infoRow(LocalizationKey.raSchedule.localized,
                        scheduled.formatted(date: .abbreviated, time: .omitted))
            } else if let done = assessment.assessedAt {
                infoRow(LocalizationKey.commonDone.localized,
                        done.formatted(date: .abbreviated, time: .shortened))
            }

            if assessment.linkedInspectionId != nil {
                infoRow(LocalizationKey.raSeededFromInspection.localized, "✓")
            }
            if let note = assessment.note, !note.isEmpty {
                infoRow(LocalizationKey.raNote.localized, note)
            }
        }
    }

    // MARK: - Lifecycle: planned → inProgress

    private var startSection: some View {
        Section {
            // Starting opens the criteria-confirmation sheet; the actual planned→inProgress
            // transition runs through the shared atomic AssessmentStart.start (WO LEGAL-2b §5) —
            // no direct status mutation / try? save here anymore.
            Button {
                showStartSheet = true
            } label: {
                Label(LocalizationKey.raStartAssessment.localized, systemImage: "play.circle.fill")
                    .font(.headline)
            }
            .accessibilityIdentifier("ra_start_assessment")
        }
    }

    // MARK: - 근로자 대표 (worker representative) — nil = 미기록 (교정 #3)

    private var workerRepSection: some View {
        Section(LocalizationKey.raWorkerRepSection.localized) {
            if isLocked {
                HStack {
                    Text(LocalizationKey.raStatus.localized).foregroundStyle(.secondary)
                    Spacer()
                    Text(assessment.workerRepStatus?.localizedLabel ?? LocalizationKey.raNotRecorded.localized)
                }
                .font(.subheadline)
            } else {
                Picker(LocalizationKey.raWorkerRepSection.localized, selection: workerRepBinding) {
                    Text(LocalizationKey.raNotRecorded.localized).tag(WorkerRepStatus?.none)
                    ForEach(WorkerRepStatus.allCases) { s in
                        Text(s.localizedLabel).tag(WorkerRepStatus?.some(s))
                    }
                }
                .accessibilityIdentifier("ra_worker_rep_picker")
            }
        }
    }

    private var workerRepBinding: Binding<WorkerRepStatus?> {
        Binding(
            get: { assessment.workerRepStatus },
            set: { assessment.workerRepStatus = $0; saveChanges() }
        )
    }

    // MARK: - 참여자 (participants)

    private var participantsSection: some View {
        Section(LocalizationKey.raParticipants.localized) {
            if participants.isEmpty {
                Text(LocalizationKey.raParticipantsEmpty.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(participants) { p in
                    if isLocked {
                        ParticipantRow(participant: p)
                    } else {
                        Button { participantSheet = .edit(p) } label: {
                            ParticipantRow(participant: p)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDelete(perform: participantDeleteAction)
            }

            if !isLocked {
                Button { participantSheet = .add } label: {
                    Label(LocalizationKey.raParticipantAdd.localized, systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("ra_add_participant")
            }
        }
    }

    /// nil while locked (finalized/cancelled) so swipe-to-delete is disabled (§7).
    private var participantDeleteAction: ((IndexSet) -> Void)? {
        guard !isLocked else { return nil }
        return deleteParticipants
    }

    private func deleteParticipants(at offsets: IndexSet) {
        let sorted = participants
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        saveChanges()
    }

    // MARK: - Items

    private var itemsSection: some View {
        // Decode the locked criteria ONCE for the whole section, not per item.
        let criteria = decodedCriteria
        return Section(LocalizationKey.raItemsSection.localized) {
            if items.isEmpty {
                Text(LocalizationKey.raItemsEmpty.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    // The 기준 이내/초과 SUGGESTION comes from the locked criteria (single Core source);
                    // it is a proposal only — nothing is recorded until the user taps 확인.
                    let suggestion = criteria?.suggestion(for: item)
                    // A decision counts as confirmed ONLY while it is CURRENT under the locked
                    // criteria (§2); a stale/incomplete record is shown as unconfirmed so the user
                    // can re-confirm.
                    let isCurrent = criteria.map { item.hasCurrentCriteriaDecision(under: $0) } ?? false
                    ItemDetailRow(item: item,
                                  method: assessment.method,
                                  stepNumber: assessment.method == .jsa ? index + 1 : nil,
                                  confirmedDecision: isCurrent ? item.criteriaDecision : nil,
                                  suggestion: suggestion,
                                  canConfirm: assessment.status == .inProgress && !isCurrent,
                                  onConfirm: { confirmDecision(item) })
                    // WO LEGAL-2c: push the item's 1:N 개선조치 management (depth-2). The summary
                    // flags a 기준 초과 item still missing its required plan.
                    correctiveActionLink(for: item)
                }
            }
        }
    }

    @ViewBuilder
    private func correctiveActionLink(for item: RiskAssessmentItem) -> some View {
        NavigationLink {
            CorrectiveActionListView(item: item, assessment: assessment)
        } label: {
            let count = (item.correctiveActions ?? []).count
            let planMissing = CorrectiveActionPolicy.isMissingRequiredCorrectiveActionPlan(item)
            HStack(spacing: 6) {
                Image(systemName: planMissing ? "exclamationmark.triangle.fill" : "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if planMissing {
                    Text(LocalizationKey.raActionPlanRequired.localized)
                } else if count > 0 {
                    Text(String(format: LocalizationKey.raActionCountFmt.localized, count))
                } else {
                    Text(LocalizationKey.raActionNone.localized)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("ra_item_actions_link")
    }

    // MARK: - Helpers

    /// Records the user's confirmation via the single atomic Core op: it decodes the locked
    /// criteria, computes + validates the decision, writes the three fields + updatedAt together,
    /// and on any failure rolls back the store AND restores the in-memory instances before
    /// rethrowing (WO LEGAL-2b P1-1). The View only surfaces the localized alert.
    private func confirmDecision(_ item: RiskAssessmentItem) {
        do {
            try AssessmentDecision.confirm(item: item, in: assessment,
                                           by: assessment.assessorName, at: Date(), context: modelContext)
        } catch {
            showSaveError = true
        }
    }

    private func saveChanges() {
        assessment.updatedAt = Date()
        try? modelContext.save()
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

/// Which participant the editor sheet is targeting: a new one (add) or an existing one (edit).
private enum ParticipantSheet: Identifiable {
    case add
    case edit(RiskAssessmentParticipant)

    var id: String {
        switch self {
        case .add:            return "add"
        case .edit(let p):    return p.id.uuidString
        }
    }

    var participant: RiskAssessmentParticipant? {
        switch self {
        case .add:            return nil
        case .edit(let p):    return p
        }
    }
}

/// One participant: name + role, with participation method / confirmation / signature
/// shown only when recorded (nil fields stay hidden — 미기록 is absence, not a value).
private struct ParticipantRow: View {
    let participant: RiskAssessmentParticipant

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(participant.name.isEmpty ? "—" : participant.name)
                    .font(.subheadline.weight(.semibold))
                RolePill(role: participant.role)
                Spacer()
                if participant.signatureData != nil {
                    Label(LocalizationKey.raSignatureCaptured.localized, systemImage: "signature")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(LocalizationKey.raSignatureCaptured.localized)
                }
            }
            HStack(spacing: 10) {
                if let method = participant.participationMethod {
                    metaLine(LocalizationKey.raParticipantMethod.localized, method.localizedLabel)
                }
                if let confirm = participant.confirmationMethod {
                    metaLine(LocalizationKey.raParticipantConfirmation.localized, confirm.localizedLabel)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func metaLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption2).foregroundStyle(.primary)
        }
    }
}

private struct RolePill: View {
    let role: ParticipantRole
    var body: some View {
        Text(role.localizedLabel)
            .font(.caption2.weight(.medium))
            .foregroundStyle(role == .workerRep ? Color.blue : Color.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill((role == .workerRep ? Color.blue : Color.secondary).opacity(0.12)))
    }
}

private struct ItemDetailRow: View {
    let item: RiskAssessmentItem
    let method: RiskAssessmentMethod
    let stepNumber: Int?   // 1-based JSA step number; nil for other methods
    let confirmedDecision: CriteriaDecision?   // non-nil ONLY when a CURRENT confirmation exists (§2)
    let suggestion: CriteriaDecision?   // computed 기준 이내/초과 proposal (nil = 위험도 미입력)
    let canConfirm: Bool                // inProgress + not currently confirmed
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    if !item.taskDescription.isEmpty || stepNumber != nil {
                        HStack(spacing: 6) {
                            if let n = stepNumber {
                                Text("\(n)")
                                    .font(.caption2.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(Color.secondary, in: Circle())
                            }
                            Text(item.taskDescription)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    if !item.hazardDescription.isEmpty {
                        Text(item.hazardDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let level = item.riskLevel {
                    RiskChip(level: level)
                } else {
                    Text(LocalizationKey.raRiskUnassessed.localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if method.usesFrequencySeverity, let l = item.likelihood, let s = item.severity {
                Text("\(LocalizationKey.raItemLikelihood.localized) \(l) × \(LocalizationKey.raItemSeverity.localized) \(s) = \(l * s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            criteriaDecisionView

            // The item's 1:N 개선조치 (measure/담당/기한/상태/효과확인) are managed on the pushed
            // CorrectiveActionListView (WO LEGAL-2c) — reached via correctiveActionLink below the row.
        }
        .padding(.vertical, 4)
    }

    /// 기준 이내/초과: the recorded decision (neutral — NOT the risk ramp) once confirmed, or a
    /// suggestion + explicit 확인 button (≥44pt) while in progress. 위험도 미입력(suggestion nil)
    /// shows nothing — 미평가 stays 미평가, with no color or 이내/초과 text (WO LEGAL-2b §6).
    @ViewBuilder private var criteriaDecisionView: some View {
        if let decision = confirmedDecision {
            HStack(spacing: 6) {
                Image(systemName: decision.systemImage).font(.caption2)
                Text(decision.localizedLabel).font(.caption2.weight(.semibold))
                if let by = item.decisionConfirmedBy, !by.isEmpty {
                    Text(String(format: LocalizationKey.raDecisionConfirmedFmt.localized, by))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        } else if canConfirm, let suggestion {
            HStack(spacing: 8) {
                Image(systemName: suggestion.systemImage).font(.caption2)
                Text(String(format: LocalizationKey.raDecisionSuggestedFmt.localized, suggestion.localizedLabel))
                    .font(.caption2)
                Spacer(minLength: 8)
                Button(LocalizationKey.raDecisionConfirm.localized, action: onConfirm)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("ra_confirm_decision")
            }
            .foregroundStyle(.secondary)
        }
    }
}
