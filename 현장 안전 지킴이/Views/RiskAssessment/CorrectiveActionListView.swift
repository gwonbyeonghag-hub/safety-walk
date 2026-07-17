import SwiftUI
import SafetyWalkCore

/// depth-2 screen (pushed from `RiskAssessmentDetailView`): the 1:N 개선조치 for ONE item
/// (WO LEGAL-2c). Reads the actions through the parent `item` relationship — no `@Query` — so
/// add/edit/delete auto-refresh here. Rows push the depth-3 editor on the same NavigationStack
/// (no nested stack, no new sheet); this screen is purely navigation — every mutation (add / edit /
/// delete) is orchestrated by `CorrectiveActionEditorViewModel`, so no persistence policy lives here
/// (CLAUDE.md MVVM). Delete lives in the editor behind a confirmation. Editable while
/// inProgress/finalized; a cancelled assessment is read-only (rows still open the editor read-only).
struct CorrectiveActionListView: View {
    let item: RiskAssessmentItem
    let assessment: RiskAssessment

    /// Deterministic order (Core single source — CloudKit doesn't preserve to-many order).
    private var actions: [CorrectiveAction] { CorrectiveActionPolicy.sortedCorrectiveActions(item) }

    /// 개선조치는 finalized 후에도 수정 가능; cancelled(및 planned)는 읽기 전용 (LEGAL_2_ARCH §1).
    private var isEditable: Bool { CorrectiveActionPolicy.allowsCorrectiveActionEditing(assessment) }

    /// 기준 초과인데 아직 개선조치 계획이 없는 상태 — 안내 배너로 노출(색 단독 아님: 아이콘+문구).
    private var planMissing: Bool { CorrectiveActionPolicy.isMissingRequiredCorrectiveActionPlan(item) }

    var body: some View {
        List {
            if planMissing {
                Section {
                    Label(LocalizationKey.raActionPlanRequired.localized,
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("ra_action_plan_required")
                }
            }

            Section {
                if actions.isEmpty {
                    Text(LocalizationKey.raActionEmpty.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(actions) { action in
                        NavigationLink {
                            // The editor VIEW is a thin value (3 refs); its ViewModel is created
                            // lazily in .onAppear, so no VM is built until the destination appears.
                            CorrectiveActionEditorView(assessment: assessment, item: item, action: action)
                        } label: {
                            CorrectiveActionRow(action: action)
                        }
                    }
                }
            } header: {
                Text(itemTitle)
            }

            if isEditable {
                Section {
                    NavigationLink {
                        CorrectiveActionEditorView(assessment: assessment, item: item, action: nil)
                    } label: {
                        Label(LocalizationKey.raActionAdd.localized, systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("ra_action_add")
                }
            }
        }
        .navigationTitle(LocalizationKey.raActionSection.localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var itemTitle: String {
        let h = item.hazardDescription.trimmingCharacters(in: .whitespaces)
        if !h.isEmpty { return h }
        let t = item.taskDescription.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? LocalizationKey.raNotRecorded.localized : t   // P3: no literal "—"
    }
}

/// Compact 1:N row: measure (title) + status · due · 효과확인 결과 (icon+text, neutral).
private struct CorrectiveActionRow: View {
    let action: CorrectiveAction

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(action.measure?.isEmpty == false ? action.measure! : LocalizationKey.raNotRecorded.localized)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)   // long measure grows vertically (Dynamic Type)
            HStack(spacing: 10) {
                Text(action.status.localizedLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let due = action.dueDate {
                    Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let result = action.effectivenessResult {
                    Label(result.localizedLabel, systemImage: result.systemImage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
