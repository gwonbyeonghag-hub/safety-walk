import SwiftUI
import SwiftData
import SafetyWalkCore

/// List of saved 위험성평가 records. Pushed from Home; "+" opens the create sheet;
/// tapping a row pushes the detail.
struct RiskAssessmentListView: View {

    // Sort by createdAt (not assessedAt) so a newly planned assessment — which has no
    // assessedAt yet — surfaces at the top instead of sinking below every conducted one.
    @Query(sort: \RiskAssessment.createdAt, order: .reverse)
    private var assessments: [RiskAssessment]

    @Environment(ProStore.self) private var proStore

    // One sheet slot (not two stacked `.sheet` modifiers, which conflict in SwiftUI):
    // the gate routes to create or paywall.
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Int, Identifiable {
        case create, plan, paywall
        var id: Int { rawValue }
    }

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
            // Separate toolbar items (not a Menu) so `ra_new_toolbar` stays a direct create
            // entry — existing RA UI tests tap it expecting the create sheet.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    startPlan()
                } label: {
                    Label(LocalizationKey.raPlanNew.localized, systemImage: "calendar.badge.plus")
                }
                .accessibilityIdentifier("ra_plan_toolbar")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    startCreate()
                } label: {
                    Label(LocalizationKey.raNew.localized, systemImage: "plus")
                }
                .accessibilityIdentifier("ra_new_toolbar")
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .create:  RiskAssessmentCreateView()
            case .plan:    PlanAssessmentView()
            case .paywall: PaywallView()
            }
        }
    }

    /// Gate A (WO-10): browsing/viewing stays free (the row `NavigationLink` → detail is
    /// never gated); authoring a new assessment is Pro, so non-subscribers get the paywall
    /// instead of the create sheet.
    private func startCreate() {
        activeSheet = proStore.isPro ? .create : .paywall
    }

    /// Same Pro gate as `startCreate()` — planning is authoring too (SCHEMA_V3 §3 lifecycle).
    private func startPlan() {
        activeSheet = proStore.isPro ? .plan : .paywall
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
            VStack(spacing: 10) {
                Button {
                    startCreate()
                } label: {
                    Label(LocalizationKey.raNew.localized, systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("ra_new_button")

                Button {
                    startPlan()
                } label: {
                    Label(LocalizationKey.raPlanNew.localized, systemImage: "calendar.badge.plus")
                }
                .accessibilityIdentifier("ra_plan_button")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// One assessment in the list: date · site · method · item count + risk distribution.
struct RiskAssessmentRowView: View {
    let assessment: RiskAssessment

    private var items: [RiskAssessmentItem] { assessment.items ?? [] }

    /// Planned records sort/display by their scheduled date; conducted ones by assessed date.
    private var rowDate: Date {
        if assessment.status == .planned, let scheduled = assessment.scheduledAt { return scheduled }
        return assessment.assessedAt ?? assessment.createdAt
    }

    private func count(_ level: RiskLevel) -> Int {
        items.filter { $0.riskLevel == level }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Planned records show their scheduled date; conducted ones their assessed date.
                Text(rowDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                if assessment.status == .planned {
                    AssessmentStatusBadge(status: .planned)
                }
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
