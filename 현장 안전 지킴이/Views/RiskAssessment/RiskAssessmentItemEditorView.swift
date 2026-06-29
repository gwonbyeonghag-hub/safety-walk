import SwiftUI
import SafetyWalkCore

/// Editor sheet for a single 위험성평가 항목. The risk-input control is
/// method-specific: 3단계 = direct 상/중/하 buttons; 빈도×강도 = likelihood × severity
/// pickers with a live score + derived band.
struct RiskAssessmentItemEditorView: View {

    let method: RiskAssessmentMethod
    let matrix: RiskMatrixConfig
    let onSave: (RiskAssessmentViewModel.DraftItem) -> Void

    @State private var draft: RiskAssessmentViewModel.DraftItem
    @Environment(\.dismiss) private var dismiss

    init(method: RiskAssessmentMethod,
         matrix: RiskMatrixConfig,
         draft: RiskAssessmentViewModel.DraftItem,
         onSave: @escaping (RiskAssessmentViewModel.DraftItem) -> Void) {
        self.method = method
        self.matrix = matrix
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    private var canSave: Bool {
        !draft.taskDescription.trimmingCharacters(in: .whitespaces).isEmpty ||
        !draft.hazardDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Live resolved band for the freq×severity inputs (nil until both chosen).
    private var derivedLevel: RiskLevel? {
        guard let l = draft.likelihood, let s = draft.severity else { return nil }
        return matrix.band(likelihood: l, severity: s)
    }
    private var derivedScore: Int? {
        guard let l = draft.likelihood, let s = draft.severity else { return nil }
        return matrix.score(likelihood: l, severity: s)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledField(method.taskFieldLabel, text: $draft.taskDescription)
                    LabeledField(LocalizationKey.raItemHazard.localized, text: $draft.hazardDescription)
                    LabeledField(LocalizationKey.raItemCurrentControls.localized, text: $draft.currentControls)
                }

                Section(LocalizationKey.raItemRiskLevel.localized) {
                    if method.usesFrequencySeverity {
                        freqSeverityInput
                    } else {
                        threeLevelInput
                    }
                }

                Section {
                    LabeledField(LocalizationKey.raItemReduction.localized, text: $draft.reductionMeasure)
                    LabeledField(LocalizationKey.raItemResponsible.localized, text: $draft.responsibleName)
                    Toggle(LocalizationKey.raItemSetDueDate.localized, isOn: $draft.hasDueDate)
                    if draft.hasDueDate {
                        DatePicker(LocalizationKey.raItemDueDate.localized,
                                   selection: $draft.dueDate, displayedComponents: .date)
                    }
                    Picker(LocalizationKey.raItemStatus.localized, selection: $draft.status) {
                        ForEach(CorrectiveActionStatus.allCases, id: \.self) { s in
                            Text(s.localizedLabel).tag(s)
                        }
                    }
                }
            }
            .navigationTitle(LocalizationKey.raItemEdit.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonDone.localized) {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - 3단계: direct 상/중/하 selection

    private var threeLevelInput: some View {
        HStack(spacing: 10) {
            ForEach([RiskLevel.high, .medium, .low], id: \.self) { level in
                let selected = draft.directRiskLevel == level
                Button {
                    draft.directRiskLevel = level
                } label: {
                    Text(level.localizedLabel)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(selected ? .white : level.uiColor)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected ? level.uiColor : level.uiColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 빈도×강도: likelihood × severity → live score + band

    private var freqSeverityInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            scalePicker(LocalizationKey.raItemLikelihood.localized,
                        scale: matrix.likelihoodScale, selection: $draft.likelihood,
                        identifier: "ra_likelihood")
            scalePicker(LocalizationKey.raItemSeverity.localized,
                        scale: matrix.severityScale, selection: $draft.severity,
                        identifier: "ra_severity")

            HStack {
                Text(LocalizationKey.raItemScore.localized)
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if let score = derivedScore, let level = derivedLevel {
                    Text("\(score)")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                    RiskChip(level: level)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func scalePicker(_ title: String, scale: Int,
                             selection: Binding<Int?>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(1...scale, id: \.self) { n in
                    Text("\(n)").tag(Optional(n))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier(identifier)
        }
    }
}

/// Single-line labeled text field used by the editor form.
private struct LabeledField: View {
    let label: String
    @Binding var text: String
    init(_ label: String, text: Binding<String>) {
        self.label = label
        _text = text
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: $text, axis: .vertical)
                .lineLimit(1...3)
        }
    }
}
