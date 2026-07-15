import SwiftUI
import SwiftData
import UIKit
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

// MARK: - Signature pad

/// Minimal finger-drawn signature capture. Strokes are collected in the pad's own
/// coordinate space and rendered to PNG `Data` (white background for report legibility)
/// on each stroke end. Optional — leaving it blank keeps `signatureData` nil.
private struct SignaturePad: View {
    @Binding var data: Data?

    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []
    @State private var padSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                canvas(strokes: strokes, current: current, color: .primary)
                if strokes.isEmpty && current.isEmpty {
                    Text(LocalizationKey.raSignatureSign.localized)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 160)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: PadSizeKey.self, value: proxy.size)
                }
            }
            .onPreferenceChange(PadSizeKey.self) { padSize = $0 }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { current.append($0.location) }
                    .onEnded { _ in
                        if !current.isEmpty { strokes.append(current); current = [] }
                        render()
                    }
            )
            .accessibilityIdentifier("participant_signature_pad")

            if !strokes.isEmpty {
                Button(role: .destructive) {
                    strokes = []; current = []; data = nil
                } label: {
                    Label(LocalizationKey.raSignatureClear.localized, systemImage: "trash")
                        .font(.caption)
                }
            }
        }
    }

    /// The stroke drawing, reused for both the on-screen pad and the off-screen render.
    private func canvas(strokes: [[CGPoint]], current: [CGPoint], color: Color) -> some View {
        Canvas { ctx, _ in
            var path = Path()
            for stroke in strokes { add(stroke, to: &path) }
            add(current, to: &path)
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    private func add(_ stroke: [CGPoint], to path: inout Path) {
        guard let first = stroke.first else { return }
        if stroke.count == 1 {
            // A tap: draw a short dot so single points are visible.
            path.addEllipse(in: CGRect(x: first.x - 1.25, y: first.y - 1.25, width: 2.5, height: 2.5))
            return
        }
        path.move(to: first)
        for p in stroke.dropFirst() { path.addLine(to: p) }
    }

    @MainActor private func render() {
        guard padSize.width > 0, padSize.height > 0 else { data = nil; return }
        let content = ZStack {
            Color.white
            canvas(strokes: strokes, current: [], color: .black)
        }
        .frame(width: padSize.width, height: padSize.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        data = renderer.uiImage?.pngData()
    }
}

private struct PadSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
