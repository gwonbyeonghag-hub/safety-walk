import SwiftUI
import SwiftData
import SafetyWalkCore

/// Read-only detail of a saved 위험성평가: header summary, each item with its
/// resolved risk band, and the non-removable disclaimer (앱은 기록만, 판정 안 함).
struct RiskAssessmentDetailView: View {
    let assessment: RiskAssessment

    // Sorted by sortOrder so JSA work steps display in their entered order
    // (CloudKit does not preserve to-many relationship order).
    private var items: [RiskAssessmentItem] {
        (assessment.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            Section {
                infoRow(LocalizationKey.raKind.localized, assessment.kind.localizedLabel)
                infoRow(LocalizationKey.raMethod.localized, assessment.method.localizedLabel)
                infoRow(LocalizationKey.raSite.localized,
                        assessment.siteName.isEmpty ? LocalizationKey.raSiteNone.localized : assessment.siteName)
                infoRow(LocalizationKey.raAssessor.localized, assessment.assessorName)
                infoRow(LocalizationKey.commonDone.localized,
                        assessment.assessedAt.formatted(date: .abbreviated, time: .shortened))
                if assessment.linkedInspectionId != nil {
                    infoRow(LocalizationKey.raSeededFromInspection.localized, "✓")
                }
                if let note = assessment.note, !note.isEmpty {
                    infoRow(LocalizationKey.raNote.localized, note)
                }
            }

            Section(LocalizationKey.raItemsSection.localized) {
                if items.isEmpty {
                    Text(LocalizationKey.raItemsEmpty.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ItemDetailRow(item: item,
                                      method: assessment.method,
                                      stepNumber: assessment.method == .jsa ? index + 1 : nil)
                    }
                }
            }

            Section {
                DisclaimerView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(LocalizationKey.raTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private struct ItemDetailRow: View {
    let item: RiskAssessmentItem
    let method: RiskAssessmentMethod
    let stepNumber: Int?   // 1-based JSA step number; nil for other methods

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    if !item.taskDescription.isEmpty || stepNumber != nil {
                        HStack(spacing: 6) {
                            if let n = stepNumber {
                                Text("\(n)")
                                    .font(.caption2.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(Color.secondary, in: Circle())
                            }
                            Text(item.taskDescription)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    if !item.hazardDescription.isEmpty {
                        Text(item.hazardDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                RiskChip(level: item.riskLevel)
            }

            if method.usesFrequencySeverity, let l = item.likelihood, let s = item.severity {
                Text("\(LocalizationKey.raItemLikelihood.localized) \(l) × \(LocalizationKey.raItemSeverity.localized) \(s) = \(l * s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let reduction = item.reductionMeasure, !reduction.isEmpty {
                detailLine(LocalizationKey.raItemReduction.localized, reduction)
            }
            if let responsible = item.responsibleName, !responsible.isEmpty {
                detailLine(LocalizationKey.raItemResponsible.localized, responsible)
            }
            if let due = item.dueDate {
                detailLine(LocalizationKey.raItemDueDate.localized,
                           due.formatted(date: .abbreviated, time: .omitted))
            }

            HStack(spacing: 6) {
                Text(LocalizationKey.raItemStatus.localized)
                    .font(.caption2).foregroundStyle(.secondary)
                Text(item.correctiveActionStatus.localizedLabel)
                    .font(.caption2.weight(.medium))
            }
        }
        .padding(.vertical, 4)
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
    }
}
