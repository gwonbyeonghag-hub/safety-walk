import SwiftUI
import SafetyWalkCore

// UI display helpers for the TBM Safety Briefing lifecycle (SCHEMA_V3 §4, WO LEGAL-TBM-2).
// `ParticipantRole`/`ConfirmationMethod` are shared with Risk Assessment — their
// `localizedLabel` extensions already live in AssessmentLifecycle+Display.swift and are
// reused as-is here (TBM_0_ARCH §4: "공유 범위 축소" — 공유 enum만, 재사용 안 함은 평가
// 전용 참여방법에만 해당).

extension BriefingStatus {
    var localizedLabel: String {
        switch self {
        case .draft:     return LocalizationKey.tbmStatusDraft.localized
        case .conducted: return LocalizationKey.tbmStatusConducted.localized
        case .finalized: return LocalizationKey.tbmStatusFinalized.localized
        case .cancelled: return LocalizationKey.tbmStatusCancelled.localized
        }
    }

    /// Neutral badge tint — workflow state, not risk (같은 원칙 AssessmentStatus.badgeColor).
    var badgeColor: Color {
        switch self {
        case .draft:     return .secondary
        case .conducted: return .blue
        case .finalized: return .green
        case .cancelled: return .secondary
        }
    }

    var systemImage: String {
        switch self {
        case .draft:     return "square.and.pencil"
        case .conducted: return "person.3.fill"
        case .finalized: return "checkmark.seal"
        case .cancelled: return "xmark.circle"
        }
    }
}

extension BriefingProfileCode {
    var localizedLabel: String {
        switch self {
        case .krTBM:             return LocalizationKey.tbmProfileKRTBM.localized
        case .usCAConstruction:  return LocalizationKey.tbmProfileUSCAConstruction.localized
        case .usElectric:        return LocalizationKey.tbmProfileUSElectric.localized
        case .usGeneral:         return LocalizationKey.tbmProfileUSGeneral.localized
        }
    }
}

/// Neutral workflow-status badge, shared by the list row and the detail header
/// (같은 형태 AssessmentStatusBadge).
struct BriefingStatusBadge: View {
    let status: BriefingStatus
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
