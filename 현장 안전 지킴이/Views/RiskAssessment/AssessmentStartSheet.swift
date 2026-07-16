import SwiftUI
import SwiftData
import SafetyWalkCore

/// 평가 시작 confirmation sheet (planned → inProgress). Shows the method's acceptability criteria
/// so the user reviews or changes them, then starts via the SINGLE shared atomic operation
/// (`AssessmentStart.start`) — the same rule the immediate create flow uses (WO LEGAL-2b §5·§6).
/// On failure the sheet stays up and shows a localized error; no partial state is left behind.
struct AssessmentStartSheet: View {
    let assessment: RiskAssessment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var threshold: Int
    @State private var showStartError = false

    init(assessment: RiskAssessment) {
        self.assessment = assessment
        let usesFS = assessment.method.usesFrequencySeverity
        _threshold = State(initialValue: AcceptabilityCriteria.makeDefault(usesFrequencySeverity: usesFS).threshold)
    }

    private var usesFrequencySeverity: Bool { assessment.method.usesFrequencySeverity }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    infoRow(LocalizationKey.raMethod.localized, assessment.method.localizedLabel)
                    infoRow(LocalizationKey.raSite.localized,
                            assessment.siteName.isEmpty ? LocalizationKey.raSiteNone.localized : assessment.siteName)
                }
                CriteriaSelectionSection(usesFrequencySeverity: usesFrequencySeverity, threshold: $threshold)
            }
            .navigationTitle(LocalizationKey.raCriteriaStartTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.raCriteriaStartButton.localized) { start() }
                        .accessibilityIdentifier("ra_criteria_start_confirm")
                }
            }
            .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $showStartError) {
                Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
            } message: {
                Text(LocalizationKey.raSaveFailedMessage.localized)
            }
        }
    }

    private func start() {
        do {
            let criteria = try AcceptabilityCriteria
                .makeDefault(usesFrequencySeverity: usesFrequencySeverity)
                .withThreshold(threshold)
            try AssessmentStart.start(assessment, criteria: criteria, now: Date(), in: modelContext)
            dismiss()
        } catch {
            showStartError = true
        }
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
