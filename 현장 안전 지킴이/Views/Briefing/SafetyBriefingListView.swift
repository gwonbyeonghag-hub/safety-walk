import SwiftUI
import SwiftData
import SafetyWalkCore

/// List of saved TBM Safety Briefing records (WO LEGAL-TBM-2 §2.4). Pushed from Home; "+"
/// opens the create sheet; tapping a row pushes the detail. 통합 조회·PDF·Mac 은 TBM-3(범위 밖).
struct SafetyBriefingListView: View {

    @Query(sort: \SafetyBriefing.createdAt, order: .reverse)
    private var briefings: [SafetyBriefing]

    @State private var showCreate = false

    var body: some View {
        Group {
            if briefings.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(briefings) { briefing in
                        NavigationLink {
                            SafetyBriefingDetailView(briefing: briefing)
                        } label: {
                            SafetyBriefingRowView(briefing: briefing)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(LocalizationKey.tbmTitle.localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Label(LocalizationKey.tbmNew.localized, systemImage: "plus")
                }
                .accessibilityIdentifier("tbm_new_toolbar")
            }
        }
        .sheet(isPresented: $showCreate) {
            SafetyBriefingCreateView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "person.3")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text(LocalizationKey.tbmEmpty.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showCreate = true
            } label: {
                Label(LocalizationKey.tbmNew.localized, systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("tbm_new_button")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// One briefing in the list: date · site · task · status badge.
struct SafetyBriefingRowView: View {
    let briefing: SafetyBriefing

    private var rowDate: Date { briefing.occurredAt ?? briefing.createdAt }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(rowDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                BriefingStatusBadge(status: briefing.status)
            }
            if !briefing.taskDescription.isEmpty {
                Text(briefing.taskDescription)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(briefing.siteName.isEmpty ? LocalizationKey.raSiteNone.localized : briefing.siteName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
