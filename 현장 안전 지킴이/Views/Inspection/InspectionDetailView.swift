import SwiftUI
import SafetyWalkCore
import SwiftData

struct InspectionDetailView: View {

    let inspection: Inspection

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showChecklist = false
    @State private var showDeleteConfirm = false

    // Read items via the @Relationship on Inspection.
    // @Query with #Predicate inside a depth-2+ pushed destination froze the app
    // on iOS 17/18 (see /navigation-qa Rule A); relationship-backed source is
    // the proven-safe pattern already used by ChecklistView and InspectionSummaryView.
    private var items: [ChecklistItem] {
        inspection.items.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Derived

    private var passCount: Int    { items.filter { $0.result == .pass }.count }
    private var failCount: Int    { items.filter { $0.result == .fail }.count }
    private var naCount: Int      { items.filter { $0.result == .notApplicable }.count }
    private var checkedCount: Int { items.filter { $0.result != .unchecked }.count }

    private var groupedItems: [(category: String, items: [ChecklistItem])] {
        var order: [String] = []
        var dict: [String: [ChecklistItem]] = [:]
        for item in items {
            if dict[item.category] == nil {
                order.append(item.category)
                dict[item.category] = []
            }
            dict[item.category]!.append(item)
        }
        return order.map { (category: $0, items: dict[$0]!) }
    }

    private var hazards: [Hazard] { inspection.hazards }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                progressCard
                if inspection.status == .inProgress {
                    continueButton
                }
                if inspection.status == .completed {
                    ShareReportButton(inspection: inspection)
                }
                checklistSection
                if !hazards.isEmpty {
                    hazardsSection
                }
                deleteButton
            }
            .padding()
        }
        .navigationTitle(inspection.siteName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showChecklist) {
            ChecklistView(inspection: inspection)
        }
        .alert(LocalizationKey.inspectionDeleteTitle.localized,
               isPresented: $showDeleteConfirm) {
            Button(LocalizationKey.commonCancel.localized, role: .cancel) { }
            Button(LocalizationKey.commonDelete.localized, role: .destructive) {
                performDelete()
            }
        } message: {
            Text(LocalizationKey.inspectionDeleteMessage.localized)
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
                statusBadge
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

    private var statusBadge: some View {
        let isCompleted = inspection.status == .completed
        return Text(isCompleted
                    ? LocalizationKey.inspectionStatusCompleted.localized
                    : LocalizationKey.inspectionStatusInProgress.localized)
            .font(.caption.weight(.medium))
            .foregroundStyle(isCompleted ? .green : .blue)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((isCompleted ? Color.green : Color.blue).opacity(0.12), in: Capsule())
    }

    // MARK: - Progress

    private var progressCard: some View {
        HStack(spacing: 0) {
            countCell(LocalizationKey.summaryPass.localized, value: passCount, color: .green)
            Divider().frame(height: 44)
            countCell(LocalizationKey.summaryFail.localized, value: failCount, color: .red)
            Divider().frame(height: 44)
            countCell(LocalizationKey.summaryNotApplicable.localized, value: naCount, color: Color(.systemGray))
            Divider().frame(height: 44)
            countCell(String(format: LocalizationKey.checklistProgress.localized, checkedCount, items.count),
                      value: nil, color: .primary)
        }
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func countCell(_ label: String, value: Int?, color: Color) -> some View {
        VStack(spacing: 4) {
            if let v = value {
                Text("\(v)")
                    .font(.title3.bold())
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Continue button

    private var continueButton: some View {
        Button {
            showChecklist = true
        } label: {
            Label(LocalizationKey.detailContinueInspection.localized,
                  systemImage: "chevron.right.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Checklist section

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizationKey.detailChecklistItems.localized)
                .font(.subheadline.weight(.semibold))

            ForEach(groupedItems, id: \.category) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(L(group.category))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(group.items) { item in
                        DetailItemRow(item: item)
                    }
                }
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Hazards section

    private var hazardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizationKey.detailLinkedHazards.localized)
                .font(.subheadline.weight(.semibold))

            ForEach(hazards) { hazard in
                HStack(spacing: 10) {
                    Circle()
                        .fill(riskColor(hazard.riskLevel))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hazard.hazardDescription)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(hazard.location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(riskLabel(hazard.riskLevel))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(riskColor(hazard.riskLevel))
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Delete (task 5-9)

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label(LocalizationKey.inspectionDelete.localized,
                  systemImage: "trash")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.bordered)
        .tint(Color.red)
    }

    private func performDelete() {
        // Snapshot photo paths before the cascade — items/hazards are removed
        // by SwiftData when the inspection is deleted (deleteRule: .cascade).
        let photoPaths: [String] =
            inspection.items.compactMap(\.photoPath) +
            inspection.hazards.map(\.photoPath)

        modelContext.delete(inspection)
        try? modelContext.save()

        // Best-effort: orphaned photo files don't block the delete.
        let storage = PhotoStorageService()
        for path in photoPaths {
            try? storage.delete(relativePath: path)
        }

        dismiss()
    }

    // MARK: - Helpers

    private func formatted(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    private func riskColor(_ level: RiskLevel) -> Color {
        switch level {
        case .low:    return .riskLow
        case .medium: return .orange
        case .high:   return .red
        }
    }

    private func riskLabel(_ level: RiskLevel) -> String {
        switch level {
        case .low:    return LocalizationKey.riskLow.localized
        case .medium: return LocalizationKey.riskMedium.localized
        case .high:   return LocalizationKey.riskHigh.localized
        }
    }
}

// MARK: - DetailItemRow

private struct DetailItemRow: View {

    let item: ChecklistItem
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            resultIcon
            Text(L(item.title))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            guard thumbnail == nil, let path = item.photoPath else { return }
            thumbnail = PhotoStorageService().load(relativePath: path)
        }
    }

    @ViewBuilder private var resultIcon: some View {
        switch item.result {
        case .pass:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .fail:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .notApplicable:
            Image(systemName: "minus.circle").foregroundStyle(Color(.systemGray))
        case .unchecked:
            Image(systemName: "circle").foregroundStyle(Color(.systemGray3))
        }
    }
}
