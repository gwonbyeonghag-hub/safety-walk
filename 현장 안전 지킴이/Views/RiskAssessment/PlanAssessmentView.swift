import SwiftUI
import SwiftData
import SafetyWalkCore

/// Creates a **planned** 위험성평가 (SCHEMA_V3 §3 lifecycle). The lightweight
/// "schedule it now, author it later" path: header + jurisdiction + scheduled date, no items —
/// items are added from the detail screen while the assessment is still `.planned`.
///
/// WO LEGAL-2d-PATH: both creation paths (this one and RiskAssessmentCreateView) now go through the
/// **same atomic Core op** `AssessmentAuthoring.create`, and both produce a `.planned` assessment.
/// Starting it (locking the criteria → `.inProgress`) happens later in the detail screen.
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
    /// 사용자가 확인해야 하는 값 — 비어 있는 상태로 시작하고 추천이 자동으로 채우지 않는다(§3).
    @State private var jurisdiction: JurisdictionCode?
    // 지역 프로파일은 추천 문구에만 쓰인다. 저장 접근은 RegionProfileStore 만 사용한다(직접 UserDefaults 금지).
    private let regionProfile = RegionProfileStore.get()

    /// SCHEMA_V3 §4.1: 현장 필수. WO LEGAL-2d-PATH §3: 관할은 저장 전 **사용자가 명시적으로 확인**해야
    /// 하므로 선택 전에는 저장할 수 없다.
    private var canSave: Bool { selectedSite != nil && jurisdiction != nil }

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

                JurisdictionSection(jurisdiction: $jurisdiction, regionProfile: regionProfile)

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

    /// 단일 원자 Core 연산으로 저장한다 — 검증·insert·commit 이 한 번에 끝나고, 실패하면 store 와
    /// 메모리 어디에도 평가가 남지 않는다. 화면은 실패 시 닫히지 않는다.
    private func save() {
        guard let site = selectedSite else { showSaveError = true; return }
        let draft = AssessmentDraft(
            kind: kind,
            method: method,
            siteId: site.id,
            siteName: site.name,
            assessorName: assessorName,
            jurisdiction: jurisdiction,
            scheduledAt: scheduledAt)
        do {
            try AssessmentAuthoring.create(draft, now: Date(), in: modelContext)
            dismiss()
        } catch {
            showSaveError = true
        }
    }
}
