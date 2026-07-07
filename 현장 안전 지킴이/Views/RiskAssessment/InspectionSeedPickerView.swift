import SwiftUI
import SwiftData
import SafetyWalkCore

/// Picker sheet for 체크리스트법: choose a completed Inspection; its failed (부적합)
/// checklist items are then seeded as assessment items by the caller.
struct InspectionSeedPickerView: View {
    let onSelect: (Inspection) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Inspection.startedAt, order: .reverse) private var inspections: [Inspection]

    private var completed: [Inspection] {
        inspections.filter { $0.status == .completed }
    }

    var body: some View {
        NavigationStack {
            Group {
                if completed.isEmpty {
                    ContentUnavailableView {
                        Label(LocalizationKey.raNoCompletedInspections.localized,
                              systemImage: "doc.text.magnifyingglass")
                    }
                } else {
                    List(completed) { inspection in
                        Button {
                            onSelect(inspection)
                            dismiss()
                        } label: {
                            InspectionPickRow(inspection: inspection)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(LocalizationKey.raPickInspection.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
            }
        }
    }
}

private struct InspectionPickRow: View {
    let inspection: Inspection
    private var failCount: Int { (inspection.items ?? []).filter { $0.result == .fail }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(inspection.siteName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(inspection.startedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let area = inspection.areaName, !area.isEmpty {
                Text(area)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Label("\(failCount)", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .accessibilityLabel("\(LocalizationKey.statusCompleted.localized) \(failCount)")
        }
        .padding(.vertical, 2)
    }
}
