import SwiftUI

/// Non-removable legal notice. Embed inline wherever the disclaimer must appear
/// (SettingsView section, InspectionSummaryView footnote, etc.).
/// Does not present a sheet or require user acceptance.
struct DisclaimerView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(LocalizationKey.disclaimerTitle.localized,
                  systemImage: "exclamationmark.shield")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(LocalizationKey.disclaimerText.localized)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: AppSurface.cornerRadius))
    }
}

#Preview {
    DisclaimerView()
        .padding()
}
