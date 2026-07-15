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

    var body: some View {
        List {
            overviewSection
            if assessment.status == .planned { startSection }
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
            Button {
                assessment.status = .inProgress
                saveChanges()
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
                    ItemDetailRow(item: item,
                                  method: assessment.method,
                                  stepNumber: assessment.method == .jsa ? index + 1 : nil)
                }
            }
        }
    }

    // MARK: - Helpers

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
