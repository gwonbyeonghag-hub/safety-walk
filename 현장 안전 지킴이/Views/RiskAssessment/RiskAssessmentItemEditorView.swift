import SwiftUI
import SafetyWalkCore

/// Editor sheet for a single 위험성평가 항목. The risk-input control is
/// method-specific: 3단계 = direct 상/중/하 buttons; 빈도×강도 = likelihood × severity
/// pickers with a live score + derived band.
struct RiskAssessmentItemEditorView: View {

    let method: RiskAssessmentMethod
    let matrix: RiskMatrixConfig
    /// 위험성 수준까지 정해져야 저장을 허용할지.
    ///
    /// 생성 화면(`false`)은 **미평가 초안**을 일부러 허용한다 — 항목을 먼저 적어두고 위험도는 나중에
    /// 정하는 흐름이며, 저장 자체는 create 화면의 `canSave` 와 Core 가 막는다(LEGAL-0).
    /// 상세 화면(`true`)은 완료 즉시 영속하므로 미평가 항목을 만들 수 없다.
    let requiresResolvedRisk: Bool
    /// 저장 결과를 돌려준다 — `false` 면 시트를 닫지 않는다. 생성 화면(초안만 모으는 경로)은 항상
    /// `true`, 상세 화면(원자 Core 연산으로 즉시 영속하는 경로)은 실패 시 `false` 를 준다.
    let onSave: (RiskAssessmentViewModel.DraftItem) -> Bool

    @State private var draft: RiskAssessmentViewModel.DraftItem
    @Environment(\.dismiss) private var dismiss

    init(method: RiskAssessmentMethod,
         matrix: RiskMatrixConfig,
         draft: RiskAssessmentViewModel.DraftItem,
         requiresResolvedRisk: Bool = false,
         onSave: @escaping (RiskAssessmentViewModel.DraftItem) -> Bool) {
        self.method = method
        self.matrix = matrix
        self.requiresResolvedRisk = requiresResolvedRisk
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    /// 작업·유해위험요인은 **항상** 비공백이어야 한다 — Core 의 항목 계약과 같은 기준이라, 화면이 더
    /// 느슨해서 저장을 눌렀다가 거부당하는 일이 없다. 위험성 수준은 즉시 영속하는 경로에서만 요구한다.
    private var canSave: Bool {
        guard !draft.taskDescription.trimmingCharacters(in: .whitespaces).isEmpty,
              !draft.hazardDescription.trimmingCharacters(in: .whitespaces).isEmpty
        else { return false }
        guard requiresResolvedRisk else { return true }
        return method.usesFrequencySeverity ? derivedLevel != nil : draft.directRiskLevel != nil
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
                        .accessibilityIdentifier("ra_item_task_field")
                    LabeledField(LocalizationKey.raItemHazard.localized, text: $draft.hazardDescription)
                        .accessibilityIdentifier("ra_item_hazard_field")
                    LabeledField(LocalizationKey.raItemCurrentControls.localized, text: $draft.currentControls)
                        .accessibilityIdentifier("ra_item_controls_field")
                }

                Section(LocalizationKey.raItemRiskLevel.localized) {
                    if method.usesFrequencySeverity {
                        freqSeverityInput
                    } else {
                        threeLevelInput
                    }
                }

                // LEGAL-2c: 최초 작성은 감소대책·담당·기한만. 상태 선택은 없앤다(최초 조치는 항상 미착수);
                // 상태·이행일·개선후위험도·효과확인은 상세의 개선조치 편집 화면에서 진행한다.
                Section {
                    LabeledField(LocalizationKey.raItemReduction.localized, text: $draft.reductionMeasure)
                    LabeledField(LocalizationKey.raItemResponsible.localized, text: $draft.responsibleName)
                    Toggle(LocalizationKey.raItemSetDueDate.localized, isOn: $draft.hasDueDate)
                    if draft.hasDueDate {
                        DatePicker(LocalizationKey.raItemDueDate.localized,
                                   selection: $draft.dueDate, displayedComponents: .date)
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
                        // 저장이 실패하면 화면을 닫지 않는다 — 호출자가 알럿을 띄운다(LEGAL-0 패턴).
                        if onSave(draft) { dismiss() }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("ra_item_done")
                }
            }
        }
    }

    // MARK: - 3단계: direct 상/중/하 selection

    private var threeLevelInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            // LEGAL-0: a seeded 참고값 is shown only as a suggestion — never auto-applied.
            // The user must tap "이 값으로 설정" for it to become the chosen level.
            if let suggested = draft.suggestedLevel {
                HStack(spacing: 8) {
                    Text(String(format: LocalizationKey.raRiskSuggestedFormat.localized,
                                suggested.localizedLabel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(LocalizationKey.raRiskApplySuggested.localized) {
                        draft.directRiskLevel = suggested
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                }
            }
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
