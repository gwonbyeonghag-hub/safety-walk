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
            workerRepSection
            participantsSection
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
        .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $showSaveError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.raSaveFailedMessage.localized)
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
        Section(LocalizationKey.raItemsSection.localized) {
            if items.isEmpty {
                Text(LocalizationKey.raItemsEmpty.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    // The 기준 이내/초과 SUGGESTION comes from the locked criteria (single Core source);
                    // it is a proposal only — nothing is recorded until the user taps 확인.
                    let criteria = decodedCriteria
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
                }
            }
        }
    }

    // MARK: - Helpers

    /// Records the user's confirmation: the Core domain op computes + validates the suggestion from
    /// the locked criteria and the item's current input, and writes the three fields together (§2)
    /// — no arbitrary decision. A confirm/validation/save failure rolls back and surfaces the
    /// localized alert (WO LEGAL-2b §2·§5).
    private func confirmDecision(_ item: RiskAssessmentItem) {
        guard let criteria = decodedCriteria else { showSaveError = true; return }
        do {
            try item.confirmCriteriaDecision(under: criteria, at: Date(), by: assessment.assessorName)
            assessment.updatedAt = Date()
            try modelContext.save()
        } catch {
            modelContext.rollback()
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

            // Improvement fields now live on CorrectiveAction (SCHEMA_V3 §4); read the item's
            // primary action for the interim single-action display.
            let action = item.primaryCorrectiveAction
            if let reduction = action?.measure, !reduction.isEmpty {
                detailLine(LocalizationKey.raItemReduction.localized, reduction)
            }
            if let responsible = action?.responsibleName, !responsible.isEmpty {
                detailLine(LocalizationKey.raItemResponsible.localized, responsible)
            }
            if let due = action?.dueDate {
                detailLine(LocalizationKey.raItemDueDate.localized,
                           due.formatted(date: .abbreviated, time: .omitted))
            }

            HStack(spacing: 6) {
                Text(LocalizationKey.raItemStatus.localized)
                    .font(.caption2).foregroundStyle(.secondary)
                Text((action?.status ?? .notStarted).localizedLabel)
                    .font(.caption2.weight(.medium))
            }
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

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
    }
}
