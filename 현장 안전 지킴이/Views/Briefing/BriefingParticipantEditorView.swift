import SwiftUI
import SwiftData
import SafetyWalkCore

/// Add a TBM briefing participant (SCHEMA_V3 §4, WO LEGAL-TBM-2 §2.3). Name required — the
/// same 생성자 계약 as 위험성평가's participant editor, but there is no edit-existing mode:
/// `BriefingParticipantEditing` exposes only `add` (a past 참석 사실 is recorded once, not
/// rewritten). `confirmationMethod`/`confirmedAt` default to **nil = 미확인**(교정 #3) —
/// never auto-filled. Signature is optional.
///
/// 참석확인의 의미(WO LEGAL-TBM-1 §4 불변식): "전달받음" 을 기록하는 것이지 책임을 면제하는
/// 서명이 아니다 — 이 화면은 그 문구를 그대로 보여준다(`tbmParticipantConfirmationHint`).
struct BriefingParticipantEditorView: View {

    let briefing: SafetyBriefing

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var role: ParticipantRole = .worker
    @State private var confirmationMethod: ConfirmationMethod?
    @State private var hasConfirmedAt = false
    @State private var confirmedAt = Date()
    @State private var signatureData: Data?
    @State private var showSaveError = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(LocalizationKey.raParticipantName.localized)
                        Spacer()
                        TextField(LocalizationKey.tbmParticipantNamePlaceholder.localized, text: $name)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("tbm_participant_name")
                    }
                    Picker(LocalizationKey.raParticipantRole.localized, selection: $role) {
                        ForEach(ParticipantRole.allCases) { r in
                            Text(r.localizedLabel).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    // 확인 방식 — 공유 enum(관리자 기록/본인 확인/서명)만. nil=미확인(교정 #3).
                    Picker(LocalizationKey.raParticipantConfirmation.localized, selection: $confirmationMethod) {
                        Text(LocalizationKey.raNotRecorded.localized).tag(ConfirmationMethod?.none)
                        ForEach(ConfirmationMethod.allCases) { c in
                            Text(c.localizedLabel).tag(ConfirmationMethod?.some(c))
                        }
                    }
                    .accessibilityIdentifier("tbm_participant_confirmation_picker")
                    Toggle(LocalizationKey.tbmParticipantConfirmedAt.localized, isOn: $hasConfirmedAt)
                    if hasConfirmedAt {
                        DatePicker(LocalizationKey.tbmParticipantConfirmedAt.localized,
                                   selection: $confirmedAt, displayedComponents: .date)
                            .labelsHidden()
                    }
                    Text(LocalizationKey.tbmParticipantConfirmationHint.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(LocalizationKey.raParticipantSignature.localized) {
                    SignaturePad(data: $signatureData)
                }
            }
            .navigationTitle(LocalizationKey.tbmParticipantAdd.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonSave.localized) { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("tbm_participant_save")
                }
            }
            .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $showSaveError) {
                Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
            } message: {
                Text(LocalizationKey.tbmParticipantSaveFailedMessage.localized)
            }
        }
    }

    /// 단일 원자 Core 연산 — 검증·insert·commit 이 한 번에 끝나고, 실패하면 store·메모리 어디에도
    /// 참석자가 남지 않는다(`BriefingParticipantEditing.add`).
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let at = hasConfirmedAt ? confirmedAt : nil
        do {
            try BriefingParticipantEditing.add(
                to: briefing, name: trimmed, role: role,
                confirmationMethod: confirmationMethod, confirmedAt: at,
                signatureData: signatureData, signedAt: signatureData != nil ? Date() : nil,
                at: Date(), context: modelContext)
            dismiss()
        } catch {
            showSaveError = true
        }
    }
}
