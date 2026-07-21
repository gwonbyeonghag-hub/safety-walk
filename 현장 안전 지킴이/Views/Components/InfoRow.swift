import SwiftUI

/// A label/value row for detail-screen overview sections — secondary label on the
/// leading edge, right-aligned value trailing. Shared by `RiskAssessmentDetailView` and
/// `SafetyBriefingDetailView` (previously two identical private copies).
func infoRow(_ label: String, _ value: String) -> some View {
    HStack {
        Text(label).foregroundStyle(.secondary)
        Spacer()
        Text(value).multilineTextAlignment(.trailing)
    }
    .font(.subheadline)
}
