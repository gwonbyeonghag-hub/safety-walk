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

extension EffectivenessResult {
    /// 효과확인 결과 라벨 (WO LEGAL-2c). "효과 있음/부분 효과/효과 없음" — 판정이 아니라 사용자 기록.
    var localizedLabel: String {
        switch self {
        case .effective:          return LocalizationKey.raEffEffective.localized
        case .partiallyEffective: return LocalizationKey.raEffPartial.localized
        case .ineffective:        return LocalizationKey.raEffIneffective.localized
        }
    }

    /// Neutral icon — effectiveness is a separate axis from the risk ramp, so it never borrows the
    /// warm risk colors (meaning comes from icon + text, not color alone — DESIGN_DIRECTION).
    var systemImage: String {
        switch self {
        case .effective:          return "checkmark.seal"
        case .partiallyEffective: return "circle.lefthalf.filled"
        case .ineffective:        return "xmark.seal"
        }
    }
}

extension SharingPhase {
    /// 사전(일정) / 사후(결과) — WO LEGAL-2d. 시점은 진입점에서 결정되며 사용자가 뒤바꾸지 못한다.
    var localizedLabel: String {
        switch self {
        case .pre:  return LocalizationKey.raSharingPre.localized
        case .post: return LocalizationKey.raSharingPost.localized
        }
    }
}

extension SharingMethod {
    /// 비TBM 공유 방법 4종. TBM 공유는 SafetyBriefing 이 증명하므로 여기에 없다(LEGAL_2_ARCH §3).
    var localizedLabel: String {
        switch self {
        case .education:  return LocalizationKey.raSharingMethodEducation.localized
        case .posting:    return LocalizationKey.raSharingMethodPosting.localized
        case .written:    return LocalizationKey.raSharingMethodWritten.localized
        case .electronic: return LocalizationKey.raSharingMethodElectronic.localized
        }
    }

    var systemImage: String {
        switch self {
        case .education:  return "person.2.wave.2"
        case .posting:    return "pin"
        case .written:    return "doc.text"
        case .electronic: return "paperplane"
        }
    }
}
