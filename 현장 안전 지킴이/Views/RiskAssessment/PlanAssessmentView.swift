import SwiftUI
import SwiftData
import SafetyWalkCore

/// Creates a **planned** 위험성평가 (SCHEMA_V3 §3 lifecycle). This is the lightweight
/// "schedule it now, assess it later" path: header + scheduled date only — no items.
/// The assessment is saved with `status = .planned` and `scheduledAt` set; risk items
/// are added after it moves to `.inProgress` (2b). The existing one-shot create flow
/// (RiskAssessmentCreateView) is untouched — that remains the "assess now" path.
struct PlanAssessmentView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Site.name) private var sites: [Site]

    @State private var kind: RiskAssessmentKind = .regular
    @State private var method: RiskAssessmentMethod = .frequencySeverity
    @State private var selectedSite: Site?
    @State private var assessorName = UserDefaults.standard.string(forKey: "com.safetywalk.inspectorName") ?? ""
    @State private var scheduledAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var showSaveError = false

    // SCHEMA_V3 §4.1: a RiskAssessment requires a site (siteId·siteName).
    private var canSave: Bool { selectedSite != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizationKey.raKind.localized) {
                    Picker(LocalizationKey.raKind.localized, selection: $kind) {
                        ForEach(RiskAssessmentKind.allCases) { k in
                            Text(k.localizedLabel).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section(LocalizationKey.raMethod.localized) {
                    Picker(LocalizationKey.raMethod.localized, selection: $method) {
                        ForEach(RiskAssessmentMethod.allCases) { m in
                            Text(m.localizedLabel).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityIdentifier("plan_method_picker")
                }

                Section {
                    sitePicker
                    HStack {
                        Text(LocalizationKey.raAssessor.localized)
                        Spacer()
                        TextField(LocalizationKey.raAssessorPlaceholder.localized, text: $assessorName)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker(LocalizationKey.raSchedule.localized,
                               selection: $scheduledAt, displayedComponents: .date)
                        .accessibilityIdentifier("plan_scheduled_date")
                }

                Section {
                    Text(LocalizationKey.raPlanHint.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(LocalizationKey.raPlanNew.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonSave.localized) { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("plan_save")
                }
            }
            .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $showSaveError) {
                Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
            } message: {
                Text(LocalizationKey.raSaveFailedMessage.localized)
            }
        }
    }

    private var sitePicker: some View {
        Menu {
            ForEach(sites) { site in
                Button(site.name) { selectedSite = site }
            }
        } label: {
            HStack {
                Text(LocalizationKey.raSite.localized).foregroundStyle(.primary)
                Spacer()
                Text(selectedSite?.name ?? LocalizationKey.raSiteNone.localized)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .accessibilityIdentifier("plan_site_picker")
    }

    private func save() {
        guard let site = selectedSite else { showSaveError = true; return }
        let assessment = RiskAssessment(
            kind: kind,
            method: method,
            siteId: site.id,
            siteName: site.name,
            assessorName: assessorName.trimmingCharacters(in: .whitespaces),
            status: .planned,
            scheduledAt: scheduledAt
        )
        // §4.1 defence-in-depth: block persisting a business-empty assessment.
        guard (try? assessment.validate()) != nil else { showSaveError = true; return }
        modelContext.insert(assessment)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            showSaveError = true
        }
    }
}
