import SwiftUI
import SafetyWalkCore

// UI display helpers for the Risk Assessment feature. Color mapping mirrors the
// rest of the app (DOMAIN_TERMS: low = gold, medium = orange, high = red),
// reusing `Color.riskLow` from Color+Risk.swift. Labels resolve through the
// active-language bundle via LocalizationKey, so they re-render on language toggle.

extension RiskLevel {
    var uiColor: Color {
        switch self {
        case .low:    return .riskLow
        case .medium: return .orange
        case .high:   return .red
        }
    }

    var localizedLabel: String {
        switch self {
        case .low:    return LocalizationKey.riskLow.localized
        case .medium: return LocalizationKey.riskMedium.localized
        case .high:   return LocalizationKey.riskHigh.localized
        }
    }
}

extension RiskAssessmentKind {
    var localizedLabel: String {
        switch self {
        case .initial:    return LocalizationKey.raKindInitial.localized
        case .regular:    return LocalizationKey.raKindRegular.localized
        case .occasional: return LocalizationKey.raKindOccasional.localized
        }
    }
}

extension RiskAssessmentMethod {
    var localizedLabel: String {
        switch self {
        case .threeLevel:        return LocalizationKey.raMethodThreeLevel.localized
        case .frequencySeverity: return LocalizationKey.raMethodFreqSeverity.localized
        case .checklist:         return LocalizationKey.raMethodChecklist.localized
        case .jsa:               return LocalizationKey.raMethodJSA.localized
        }
    }

    /// "공정·작업" for most methods; "작업 단계" (Job Step) for JSA.
    var taskFieldLabel: String {
        self == .jsa ? LocalizationKey.raJsaStep.localized : LocalizationKey.raItemTask.localized
    }
}

extension CorrectiveActionStatus {
    var localizedLabel: String {
        switch self {
        case .notStarted: return LocalizationKey.statusNotStarted.localized
        case .inProgress: return LocalizationKey.statusInProgress.localized
        case .completed:  return LocalizationKey.statusCompleted.localized
        }
    }
}
