import SwiftUI
import SafetyWalkCore
import SwiftData

struct InspectionSummaryView: View {

    let inspection: Inspection

    @Environment(\.dismiss) private var dismiss

    // Read items via the @Relationship on Inspection.
    // @Query with #Predicate inside a depth-2+ pushed destination froze the app;
    // relationship-backed source is the proven-safe pattern.
    private var items: [ChecklistItem] {
        inspection.items.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Derived counts

    private var passCount: Int  { items.filter { $0.result == .pass }.count }
    private var failCount: Int  { items.filter { $0.result == .fail }.count }
    private var naCount: Int    { items.filter { $0.result == .notApplicable }.count }
    private var failedItems: [ChecklistItem] { items.filter { $0.result == .fail } }

    private var hazards: [Hazard] { inspection.hazards }
    private var lowCount: Int    { hazards.filter { $0.riskLevel == .low }.count }
    private var mediumCount: Int { hazards.filter { $0.riskLevel == .medium }.count }
    private var highCount: Int   { hazards.filter { $0.riskLevel == .high }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                countsCard
                if !hazards.isEmpty { hazardRiskCard }
                if !failedItems.isEmpty { failedItemsSection }
                shareButtonPlaceholder
            }
            .padding()
        }
        .navigationTitle(LocalizationKey.summaryTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(LocalizationKey.commonDone.localized) { dismiss() }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(inspection.siteName)
                        .font(.title3.weight(.semibold))
                    if let area = inspection.areaName, !area.isEmpty {
                        Text(area)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(LocalizationKey.inspectionStatusCompleted.localized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.green.opacity(0.12), in: Capsule())
            }

            Divider()

            if !inspection.inspectorName.isEmpty {
                Label(inspection.inspectorName, systemImage: "person")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Label(
                "\(LocalizationKey.summaryStartedAt.localized): \(formatted(inspection.startedAt))",
                systemImage: "calendar"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if let completedAt = inspection.completedAt {
                Label(
                    "\(LocalizationKey.summaryCompletedAt.localized): \(formatted(completedAt))",
                    systemImage: "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Counts

    private var countsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizationKey.summaryTotalItems.localized)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 0) {
                countCell(LocalizationKey.summaryPass.localized, value: passCount, color: .green)
                Divider().frame(height: 44)
                countCell(LocalizationKey.summaryFail.localized, value: failCount, color: .red)
                Divider().frame(height: 44)
                countCell(LocalizationKey.summaryNotApplicable.localized, value: naCount, color: Color(.systemGray))
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func countCell(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hazards by risk

    private var hazardRiskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizationKey.summaryHazardsByRisk.localized)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 0) {
                riskCell(LocalizationKey.riskHigh.localized, count: highCount, color: .red)
                Divider().frame(height: 44)
                riskCell(LocalizationKey.riskMedium.localized, count: mediumCount, color: .orange)
                Divider().frame(height: 44)
                riskCell(LocalizationKey.riskLow.localized, count: lowCount, color: .riskLow)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func riskCell(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(count > 0 ? color : Color(.systemGray))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Failed items

    private var failedItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizationKey.summaryFailedItems.localized)
                .font(.subheadline.weight(.semibold))

            ForEach(failedItems) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.top, 2)
                    Text(L(item.title))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Share

    private var shareButtonPlaceholder: some View {
        ShareReportButton(inspection: inspection)
    }

    // MARK: - Helper

    private func formatted(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
}
