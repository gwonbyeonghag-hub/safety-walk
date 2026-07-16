import SwiftUI
import SafetyWalkCore

// WO LEGAL-2b — the 허용 기준(acceptability criteria) UI vocabulary, shared by BOTH start paths
// (the planned "평가 시작" sheet and the immediate create form) plus the read-only locked display.
// Wording is "사업장 설정 기준 이내/초과" only — never 허용/불허용/위반/준수 (앱은 법적 판정을 하지 않음).

/// The selectable "highest within-criteria" options for a method — the VALUES come from Core's
/// single allowed set (`AcceptabilityCriteria.allowedThresholds`, WO §3), the UI only maps each to
/// its label: 빈도×강도/JSA → raw score 2/4; 3단계/체크리스트 → level rank 1(낮음만)/2(낮음·보통).
func criteriaThresholdOptions(usesFrequencySeverity: Bool) -> [(value: Int, label: LocalizationKey)] {
    AcceptabilityCriteria.allowedThresholds(usesFrequencySeverity: usesFrequencySeverity).map { value in
        (value, criteriaThresholdLabelKey(value, usesFrequencySeverity: usesFrequencySeverity))
    }
}

private func criteriaThresholdLabelKey(_ value: Int, usesFrequencySeverity: Bool) -> LocalizationKey {
    if usesFrequencySeverity {
        return value == 4 ? .raCriteriaScoreOption4 : .raCriteriaScoreOption2
    } else {
        return value == 2 ? .raCriteriaLevelMedium : .raCriteriaLevelLow
    }
}

extension CriteriaDecision {
    /// "사업장 설정 기준 이내 / 초과" — the only permitted decision wording (교정 #6).
    var localizedLabel: String {
        switch self {
        case .withinThreshold:  return LocalizationKey.raDecisionWithin.localized
        case .exceedsThreshold: return LocalizationKey.raDecisionExceeds.localized
        }
    }

    /// Neutral icon — the decision is a criteria comparison, NOT a risk level, so it never
    /// borrows the warm risk ramp (DESIGN_DIRECTION: risk colors mean risk only).
    var systemImage: String {
        switch self {
        case .withinThreshold:  return "checkmark.circle"
        case .exceedsThreshold: return "exclamationmark.circle"
        }
    }
}

/// Editable criteria section used before an assessment starts (both paths). Explains that the
/// values are site-set (not legal), then offers the method's two threshold options.
struct CriteriaSelectionSection: View {
    let usesFrequencySeverity: Bool
    @Binding var threshold: Int

    var body: some View {
        Section(LocalizationKey.raCriteriaSection.localized) {
            Text((usesFrequencySeverity ? LocalizationKey.raCriteriaExplainScore
                                        : LocalizationKey.raCriteriaExplainLevel).localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(LocalizationKey.raCriteriaThreshold.localized, selection: $threshold) {
                ForEach(criteriaThresholdOptions(usesFrequencySeverity: usesFrequencySeverity), id: \.value) { option in
                    Text(option.label.localized).tag(option.value)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .accessibilityIdentifier("ra_criteria_threshold_picker")
        }
    }
}

/// Read-only display of the LOCKED criteria on an in-progress/finalized assessment. Fail-closed:
/// if the stored snapshot can't be decoded it says so rather than inventing a default.
struct LockedCriteriaSection: View {
    let criteria: AssessmentCriteria
    let usesFrequencySeverity: Bool

    private var decoded: AcceptabilityCriteria? {
        try? AcceptabilityCriteria.decode(
            matrixData: criteria.matrixData,
            matrixFormatVersion: criteria.matrixFormatVersion,
            threshold: criteria.acceptabilityThreshold,
            usesFrequencySeverity: usesFrequencySeverity)
    }

    private var thresholdLabel: String? {
        criteriaThresholdOptions(usesFrequencySeverity: usesFrequencySeverity)
            .first { $0.value == criteria.acceptabilityThreshold }
            .map { $0.label.localized }
    }

    var body: some View {
        Section(LocalizationKey.raCriteriaLocked.localized) {
            if decoded != nil, let label = thresholdLabel {
                HStack {
                    Text(LocalizationKey.raCriteriaThreshold.localized)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(label).multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
                Text(LocalizationKey.raCriteriaLockedHint.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // fail-closed: undecodable snapshot → surfaced, never silently defaulted.
                Label(LocalizationKey.raCriteriaCorrupt.localized, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("ra_criteria_corrupt")
            }
        }
    }
}
