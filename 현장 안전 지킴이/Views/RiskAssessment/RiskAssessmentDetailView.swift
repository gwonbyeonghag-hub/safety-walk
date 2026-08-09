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
    @Environment(\.dismiss) private var dismiss
    @State private var participantSheet: ParticipantSheet?
    @State private var showStartSheet = false
    @State private var showSaveError = false
    /// 공유 기록 시트의 시점 — 진입점(planned=사전 / finalized=사후)이 정하며 시트 안에서 바꿀 수 없다.
    @State private var sharingSheetPhase: SharingPhase?
    @State private var showFinalizeError = false
    /// 항목 편집 시트 (추가/수정) — WO LEGAL-2d-PATH §4.
    @State private var itemSheet: ItemSheet?
    @State private var showItemError = false
    @State private var finalizeErrorMessage = LocalizationKey.raFinalizeFailedMessage.localized
    // WO LEGAL-2e — 평가 삭제.
    @State private var showDeleteConfirm = false
    @State private var showDeleteError = false

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
            deleteSection
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
        .sheet(item: $itemSheet) { sheet in
            // 기존 항목 편집기를 그대로 재사용한다 — 중복 폼을 만들지 않는다(WO LEGAL-2d-PATH §4).
            // 편집기의 실시간 밴드는 Core 가 저장에 쓰는 것과 **같은 매트릭스**를 써야 한다 —
            // 3×3 을 하드코딩하면 잠긴 기준이 다른 매트릭스일 때 화면과 저장값이 어긋난다.
            RiskAssessmentItemEditorView(
                method: assessment.method,
                matrix: editorMatrix,
                draft: sheet.draft(for: assessment.method),
                requiresResolvedRisk: true) { edited in
                    saveItem(edited, existing: sheet.item)
                }
        }
        .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $showItemError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.raItemSaveFailed.localized)
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
        .alert(LocalizationKey.raDeleteTitle.localized, isPresented: $showDeleteConfirm) {
            Button(LocalizationKey.commonCancel.localized, role: .cancel) { }
            Button(LocalizationKey.commonDelete.localized, role: .destructive) { performDelete() }
        } message: {
            Text(deleteAlertMessage)
        }
        .alert(LocalizationKey.raDeleteFailedTitle.localized, isPresented: $showDeleteError) {
            Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.raDeleteFailedMessage.localized)
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

            // 종결(closed)은 저장 상태가 아니라 파생이다(LEGAL_2_ARCH §1.1) — 확정 이후에만,
            // 그리고 **사실형**으로만 보여준다("평가완료 · 개선조치 N건 진행 중").
            if assessment.status == .finalized {
                closedStatusRow
            }

            infoRow(LocalizationKey.raKind.localized, assessment.kind.localizedLabel)
            infoRow(LocalizationKey.raMethod.localized, assessment.method.localizedLabel)
            infoRow(LocalizationKey.raSite.localized,
                    assessment.siteName.isEmpty ? LocalizationKey.raSiteNone.localized : assessment.siteName)
            infoRow(LocalizationKey.raAssessor.localized, assessment.assessorName)
            // WO LEGAL-3A: 저장된 업종 스냅샷 — 과거 평가는 현재 설정이 아니라 그 평가의 값을 보여준다.
            infoRow(LocalizationKey.raIndustry.localized,
                    assessment.industryDisplayText)

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
            // WO LEGAL-2e — 3년 보존(시행규칙 제37조의4) 안내. 앱 가드일 뿐 자동 법 판정이 아니다.
            infoRow(LocalizationKey.raRetainUntil.localized, assessment.retainUntilDisplayText)
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
            }
            itemRows(criteria: criteria)
            // WO LEGAL-2d-PATH §4: 항목은 planned/inProgress 에서 작성·수정한다 (finalized 에 잠김).
            // 계획만 먼저 세운 평가도 여기서 항목을 채울 수 있어야 시작·확정까지 갈 수 있다.
            if canEditItems {
                Button { itemSheet = .add } label: {
                    Label(LocalizationKey.raItemAdd.localized, systemImage: "plus.circle")
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("ra_add_item")
            }
        }
    }

    /// 항목 편집 가능 여부 — Core 규칙과 같은 단일 소스.
    private var canEditItems: Bool { AssessmentItemEditing.allowsItemEditing(assessment) }

    /// 항목 편집기가 쓸 매트릭스 — 잠긴 기준이 있으면 그것, 없으면(planned) 기법 기본값.
    /// Core 의 `AssessmentItemEditing.matrix(for:)` 와 같은 규칙이라 화면과 저장값이 어긋나지 않는다.
    /// 기준이 손상돼 읽을 수 없으면 Core 가 저장을 거부하므로, 화면은 기본값으로 그리되 저장은 막힌다.
    private var editorMatrix: RiskMatrixConfig {
        guard let decoded = decodedCriteria else { return RiskMatrixConfig.threeByThree }
        return decoded.matrix.asRiskMatrixConfig
    }

    /// 종결 여부와 **미종결 사유**를 모두 Core 파생(`AssessmentClosure`)에서 읽는다. 화면이 사유를 따로
    /// 추측하면 실제로 막고 있는 조건과 어긋난다(예: 필수 조치가 0건인데 사후 공유가 없어 미종결인 경우
    /// "개선조치 0건 진행 중"이라고 말하게 된다). 사실만 말하고 판정 문구는 쓰지 않는다.
    @ViewBuilder
    private var closedStatusRow: some View {
        HStack(alignment: .top) {
            Text(LocalizationKey.raStatusSection.localized).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if let reason = AssessmentClosure.openReason(assessment, in: modelContext) {
                Text(openReasonText(reason))
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("ra_closed_no")
            } else {
                Label(LocalizationKey.raStatusClosed.localized, systemImage: "checkmark.seal")
                    .labelStyle(.titleAndIcon)
                    .accessibilityIdentifier("ra_closed_yes")
            }
        }
        .font(.subheadline)
    }

    private func openReasonText(_ reason: AssessmentClosure.OpenReason) -> String {
        switch reason {
        case .notFinalized, .criteriaUnavailable:
            return LocalizationKey.raStatusOpenCriteria.localized
        case .noItems:
            return LocalizationKey.raStatusOpenNoItems.localized
        case .itemsIncomplete(let count):
            return String(format: LocalizationKey.raStatusOpenItemsFmt.localized, count)
        case .correctiveActionsOpen(let count):
            return String(format: LocalizationKey.raStatusActionsOpenFmt.localized, count)
        case .postSharingMissing:
            return LocalizationKey.raStatusOpenPostSharing.localized
        }
    }

    @ViewBuilder
    private func itemRows(criteria: AcceptabilityCriteria?) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            // The 기준 이내/초과 SUGGESTION comes from the locked criteria (single Core source);
            // it is a proposal only — nothing is recorded until the user taps 확인.
            let suggestion = criteria?.suggestion(for: item)
            // A decision counts as confirmed ONLY while it is CURRENT under the locked
            // criteria (§2); a stale/incomplete record is shown as unconfirmed so the user
            // can re-confirm.
            let isCurrent = criteria.map { item.hasCurrentCriteriaDecision(under: $0) } ?? false
            let row = ItemDetailRow(item: item,
                                    method: assessment.method,
                                    stepNumber: assessment.method == .jsa ? index + 1 : nil,
                                    confirmedDecision: isCurrent ? item.criteriaDecision : nil,
                                    suggestion: suggestion,
                                    canConfirm: assessment.status == .inProgress && !isCurrent,
                                    onConfirm: { confirmDecision(item) })
            // 편집·삭제는 **행 단위 swipeActions** 로 단다.
            // `.onDelete` 를 쓰지 않는 이유: 이 ForEach 는 항목마다 행을 둘(항목 요약 + 개선조치 링크)
            // 만들기 때문에 IndexSet 이 항목 인덱스와 어긋난다 — 엉뚱한 항목이 지워질 수 있다.
            // swipeActions 는 자기 행에 직접 붙으므로 그런 매핑이 아예 없다.
            // ⚠️ 행 컨테이너에는 accessibilityIdentifier 를 붙이지 않는다 — 자식(예: 결정 '확인'
            // 버튼의 `ra_confirm_decision`)의 식별자를 덮어써서 테스트가 그 버튼을 찾지 못한다.
            row
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if canEditItems {
                        Button(role: .destructive) { deleteItem(item) } label: {
                            Label(LocalizationKey.raItemDelete.localized, systemImage: "trash")
                        }
                        .accessibilityIdentifier("ra_item_delete")
                        Button { itemSheet = .edit(item) } label: {
                            Label(LocalizationKey.raItemEdit.localized, systemImage: "pencil")
                        }
                        .accessibilityIdentifier("ra_item_edit")
                    }
                }
            // WO LEGAL-2c: push the item's 1:N 개선조치 management (depth-2). The summary
            // flags a 기준 초과 item still missing its required plan.
            correctiveActionLink(for: item)
        }
    }

    private func deleteItem(_ item: RiskAssessmentItem) {
        do {
            try AssessmentItemEditing.remove(item, in: assessment, at: Date(), context: modelContext)
        } catch {
            showItemError = true
        }
    }

    /// 항목 저장 — 추가·수정 모두 Core 의 원자 연산을 지난다. 실패하면 시트를 닫지 않는다.
    private func saveItem(_ draft: RiskAssessmentViewModel.DraftItem,
                          existing: RiskAssessmentItem?) -> Bool {
        let level = assessment.method.usesFrequencySeverity
            ? nil : draft.directRiskLevel
        do {
            if let existing {
                try AssessmentItemEditing.update(
                    existing, in: assessment,
                    task: draft.taskDescription, hazard: draft.hazardDescription,
                    currentControls: draft.currentControls,
                    likelihood: draft.likelihood, severity: draft.severity, riskLevel: level,
                    at: Date(), context: modelContext)
            } else {
                try AssessmentItemEditing.add(
                    to: assessment,
                    task: draft.taskDescription, hazard: draft.hazardDescription,
                    currentControls: draft.currentControls,
                    likelihood: draft.likelihood, severity: draft.severity, riskLevel: level,
                    linkedHazardId: draft.linkedHazardId,
                    at: Date(), context: modelContext)
            }
            return true
        } catch {
            showItemError = true
            return false
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

    // MARK: - 삭제 (WO LEGAL-2e)

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(LocalizationKey.raDelete.localized, systemImage: "trash")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("ra_delete_assessment")
        }
    }

    /// 보존 기간 내면 경고를 앞에 얹는다 — 하드 차단이 아니라 사용자가 확인하면 그대로 삭제할 수 있다
    /// (CLAUDE.md No legal judgment). 보존 기간이 지났으면 표준 삭제 안내만 보인다.
    ///
    /// `isWithinRetentionPeriod` 는 날짜 계산이 실패해도 fail-closed 로 true 를 반환한다
    /// (`RetentionPolicy` 참고) — 그 경우에도 경고는 그대로 띄우고, 날짜 표시만 `retainUntilDisplayText`
    /// 의 "—" 폴백을 쓴다. 두 계산을 따로 요구해 경고가 조용히 사라지지 않게 한다.
    private var deleteAlertMessage: String {
        guard RetentionPolicy.isWithinRetentionPeriod(assessment, now: Date()) else {
            return LocalizationKey.raDeleteMessage.localized
        }
        let warning = String(format: LocalizationKey.raDeleteRetentionWarningFmt.localized,
                             assessment.retainUntilDisplayText)
        return warning + "\n\n" + LocalizationKey.raDeleteMessage.localized
    }

    /// 삭제는 Core 의 단일 원자 연산을 거친다 — cascade(기준·항목·참여자·공유이력)는 SwiftData 가 지운다.
    private func performDelete() {
        do {
            try AssessmentDeletion.delete(assessment, in: modelContext)
            dismiss()
        } catch {
            showDeleteError = true
        }
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
}

/// 항목 편집 시트의 대상 — 새 항목(add) 또는 기존 항목(edit). 기존 `RiskAssessmentItemEditorView` 를
/// 그대로 쓰기 위해 저장된 항목을 그 화면의 `DraftItem` 값으로 옮겨 담는다(중복 폼 금지).
private enum ItemSheet: Identifiable {
    case add
    case edit(RiskAssessmentItem)

    var id: String {
        switch self {
        case .add:         return "add"
        case .edit(let i): return i.id.uuidString
        }
    }

    var item: RiskAssessmentItem? {
        switch self {
        case .add:         return nil
        case .edit(let i): return i
        }
    }

    func draft(for method: RiskAssessmentMethod) -> RiskAssessmentViewModel.DraftItem {
        guard let item else { return RiskAssessmentViewModel.DraftItem() }
        var d = RiskAssessmentViewModel.DraftItem()
        d.taskDescription = item.taskDescription
        d.hazardDescription = item.hazardDescription
        d.currentControls = item.currentControls ?? ""
        d.likelihood = item.likelihood
        d.severity = item.severity
        // 3단계/체크리스트는 직접 선택값을, 빈도×강도는 가능성·중대성에서 파생하므로 비워 둔다.
        d.directRiskLevel = method.usesFrequencySeverity ? nil : item.riskLevel
        d.linkedHazardId = item.linkedHazardId
        return d
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
