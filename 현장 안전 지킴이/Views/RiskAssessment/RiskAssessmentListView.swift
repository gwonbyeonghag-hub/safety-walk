import SwiftUI
import SwiftData
import SafetyWalkCore

/// List of saved 위험성평가 records. Pushed from Home; "+" opens the create sheet;
/// tapping a row pushes the detail.
struct RiskAssessmentListView: View {

    @Query(sort: \RiskAssessment.assessedAt, order: .reverse)
    private var assessments: [RiskAssessment]

    @State private var showCreate = false

    var body: some View {
        Group {
            if assessments.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(assessments) { assessment in
                        NavigationLink {
                            RiskAssessmentDetailView(assessment: assessment)
                        } label: {
                            RiskAssessmentRowView(assessment: assessment)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(LocalizationKey.raTitle.localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Label(LocalizationKey.raNew.localized, systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            RiskAssessmentCreateView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "list.clipboard")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text(LocalizationKey.raEmpty.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showCreate = true
            } label: {
                Label(LocalizationKey.raNew.localized, systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// One assessment in the list: date · site · method · item count + risk distribution.
struct RiskAssessmentRowView: View {
    let assessment: RiskAssessment

    private var items: [RiskAssessmentItem] { assessment.items ?? [] }

    private func count(_ level: RiskLevel) -> Int {
        items.filter { $0.riskLevel == level }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(assessment.assessedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(assessment.method.localizedLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.5), in: Capsule())
            }

            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(assessment.siteName.isEmpty ? LocalizationKey.raSiteNone.localized : assessment.siteName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: LocalizationKey.raItemCountFormat.localized, items.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !items.isEmpty {
                HStack(spacing: 10) {
                    ForEach([RiskLevel.high, .medium, .low], id: \.self) { level in
                        let c = count(level)
                        if c > 0 {
                            HStack(spacing: 4) {
                                RiskDot(level: level)
                                Text("\(c)")
                                    .font(.caption2).monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
