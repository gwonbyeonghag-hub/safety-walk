import SwiftUI
import SafetyWalkCore

// UI display helpers for the 2a lifecycle + participant vocabulary (SCHEMA_V3 §3).
// Labels resolve through the active-language bundle via LocalizationKey so they
// re-render on a language toggle, mirroring RiskLevel+Display.swift. Optional
// fields (participationMethod / confirmationMethod / workerRepStatus) render their
// nil state as "미기록" at the call site — never as a real value (LEGAL-0 / 교정 #3).

extension AssessmentStatus {
    var localizedLabel: String {
        switch self {
        case .planned:    return LocalizationKey.raStatusPlanned.localized
        case .inProgress: return LocalizationKey.raStatusInProgress.localized
        case .finalized:  return LocalizationKey.raStatusFinalized.localized
        case .cancelled:  return LocalizationKey.raStatusCancelled.localized
        }
    }

    /// Neutral badge tint — status is workflow state, NOT risk, so it never borrows the
    /// warm risk ramp (DESIGN_DIRECTION: the risk colors mean risk only).
    var badgeColor: Color {
        switch self {
        case .planned:    return .secondary
        case .inProgress: return .blue
        case .finalized:  return .green
        case .cancelled:  return .secondary
        }
    }

    var systemImage: String {
        switch self {
        case .planned:    return "calendar"
        case .inProgress: return "pencil.and.list.clipboard"
        case .finalized:  return "checkmark.seal"
        case .cancelled:  return "xmark.circle"
        }
    }
}

extension ParticipantRole {
    var localizedLabel: String {
        switch self {
        case .worker:    return LocalizationKey.raRoleWorker.localized
        case .workerRep: return LocalizationKey.raRoleWorkerRep.localized
        }
    }
}

extension AssessmentParticipationMethod {
    var localizedLabel: String {
        switch self {
        case .patrol:    return LocalizationKey.raPartMethodPatrol.localized
        case .interview: return LocalizationKey.raPartMethodInterview.localized
        case .survey:    return LocalizationKey.raPartMethodSurvey.localized
        case .other:     return LocalizationKey.raPartMethodOther.localized
        }
    }
}

extension ConfirmationMethod {
    var localizedLabel: String {
        switch self {
        case .managerRecord: return LocalizationKey.raConfirmManagerRecord.localized
        case .selfConfirm:   return LocalizationKey.raConfirmSelfConfirm.localized
        case .signature:     return LocalizationKey.raConfirmSignature.localized
        }
    }
}

extension WorkerRepStatus {
    var localizedLabel: String {
        switch self {
        case .notRequested:             return LocalizationKey.raWorkerRepNotRequested.localized
        case .requestedNotParticipated: return LocalizationKey.raWorkerRepRequestedNotParticipated.localized
        case .participated:             return LocalizationKey.raWorkerRepParticipated.localized
        }
    }
}

/// Neutral workflow-status badge (icon + label), tinted by `AssessmentStatus.badgeColor`.
/// Shared by the list row and the detail header so status reads the same everywhere.
struct AssessmentStatusBadge: View {
    let status: AssessmentStatus
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.systemImage)
                .font(.caption2)
            Text(status.localizedLabel)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(status.badgeColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(status.badgeColor.opacity(0.14)))
        .overlay(Capsule().strokeBorder(status.badgeColor.opacity(0.30), lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.localizedLabel)
    }
}
