import SwiftUI
import SwiftData
import SafetyWalkCore

/// Add / edit a 위험성평가 participant (SCHEMA_V3 §4·§4.1). Name is required — the
/// validated `RiskAssessmentParticipant` initializer + `validate()` reject a blank
/// one (생성자 계약). `participationMethod` / `confirmationMethod` / `participatedAt`
/// are optional and default to **nil = 미기록** — they are never auto-filled with a
/// real value (교정 #3). Signature is optional.
struct ParticipantEditorView: View {

    let assessment: RiskAssessment
    /// nil = add mode; non-nil = edit an existing participant in place.
    var existing: RiskAssessmentParticipant?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var role: ParticipantRole = .worker
    // nil = 미기록 (교정 #3): the picker offers an explicit "미기록" option, never a default value.
    @State private var participationMethod: AssessmentParticipationMethod?
    @State private var hasParticipatedAt = false
    @State private var participatedAt = Date()
    @State private var confirmationMethod: ConfirmationMethod?
    @State private var signatureData: Data?

    private var isEditing: Bool { existing != nil }

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
                        TextField(LocalizationKey.raParticipantNamePlaceholder.localized, text: $name)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("participant_name")
                    }
                    Picker(LocalizationKey.raParticipantRole.localized, selection: $role) {
                        ForEach(ParticipantRole.allCases) { r in
                            Text(r.localizedLabel).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    // 참여 방법 — 평가 전용 순회/면담/설문/기타. nil=미기록.
                    Picker(LocalizationKey.raParticipantMethod.localized, selection: $participationMethod) {
                        Text(LocalizationKey.raNotRecorded.localized).tag(AssessmentParticipationMethod?.none)
                        ForEach(AssessmentParticipationMethod.allCases) { m in
                            Text(m.localizedLabel).tag(AssessmentParticipationMethod?.some(m))
                        }
                    }
                    Toggle(LocalizationKey.raParticipantParticipatedAt.localized, isOn: $hasParticipatedAt)
                    if hasParticipatedAt {
                        DatePicker(LocalizationKey.raParticipantParticipatedAt.localized,
                                   selection: $participatedAt, displayedComponents: .date)
                            .labelsHidden()
                    }
                }

                Section {
                    // 확인 방식 — 관리자 기록/본인 확인/서명. nil=미확인.
                    Picker(LocalizationKey.raParticipantConfirmation.localized, selection: $confirmationMethod) {
                        Text(LocalizationKey.raNotRecorded.localized).tag(ConfirmationMethod?.none)
                        ForEach(ConfirmationMethod.allCases) { c in
                            Text(c.localizedLabel).tag(ConfirmationMethod?.some(c))
                        }
                    }
                }

                Section(LocalizationKey.raParticipantSignature.localized) {
                    SignaturePad(data: $signatureData)
                }
            }
            .navigationTitle(isEditing ? LocalizationKey.raParticipantEdit.localized
                                       : LocalizationKey.raParticipantAdd.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonSave.localized) { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("participant_save")
                }
            }
            .onAppear(perform: populateFromExisting)
        }
    }

    private func populateFromExisting() {
        guard let p = existing else { return }
        name = p.name
        role = p.role
        participationMethod = p.participationMethod
        if let at = p.participatedAt { hasParticipatedAt = true; participatedAt = at }
        confirmationMethod = p.confirmationMethod
        signatureData = p.signatureData
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let at = hasParticipatedAt ? participatedAt : nil
        let signedAt: Date? = signatureData != nil ? (existing?.signedAt ?? Date()) : nil

        if let p = existing {
            // Edit in place. Guard the required-name invariant before persisting.
            p.name = trimmed
            p.role = role
            p.participationMethod = participationMethod
            p.participatedAt = at
            p.confirmationMethod = confirmationMethod
            p.signatureData = signatureData
            p.signedAt = signedAt
            guard (try? p.validate()) != nil else { return }
        } else {
            // New: build through the validated initializer (name·role required, §4.1).
            let participant = RiskAssessmentParticipant(
                name: trimmed,
                role: role,
                participationMethod: participationMethod,
                participatedAt: at,
                confirmationMethod: confirmationMethod
            )
            participant.signatureData = signatureData
            participant.signedAt = signedAt
            // insert/finalize 전 검증 실패 시 저장 금지 (빈 모델 차단, §4.1).
            guard (try? participant.validate()) != nil else { return }
            modelContext.insert(participant)
            participant.riskAssessment = assessment
            var list = assessment.participants ?? []
            list.append(participant)
            assessment.participants = list
        }
        assessment.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}
