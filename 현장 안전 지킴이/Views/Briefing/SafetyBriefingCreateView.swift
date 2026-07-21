import SwiftUI
import SwiftData
import SafetyWalkCore

/// Creates a **draft** TBM Safety Briefing (SCHEMA_V3 §4, WO LEGAL-TBM-2 §2.1). Site is the
/// only required field (§4.1 생성자 계약) — everything else, including the optional linked
/// 위험성평가, is set here at creation time. There is no Core operation to change the link
/// afterward (`BriefingLifecycle.conduct` only reads it), so re-linking is out of this
/// screen's scope by design — a briefing that should be linked differently is a new briefing.
struct SafetyBriefingCreateView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Site.name) private var sites: [Site]
    @Query(sort: \RiskAssessment.createdAt, order: .reverse) private var assessments: [RiskAssessment]

    @State private var taskDescription = ""
    @State private var hasOccurredAt = false
    @State private var occurredAt = Date()
    @State private var location = ""
    @State private var selectedSite: Site?
    @State private var briefingProfile: BriefingProfileCode?
    @State private var linkedAssessment: RiskAssessment?
    @State private var showSaveError = false

    /// SCHEMA_V3 §4.1: Site 필수. 관할 프로필·일시·장소·연결 평가는 모두 선택.
    private var canSave: Bool { selectedSite != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(LocalizationKey.tbmTaskDescription.localized)
                        Spacer()
                        TextField(LocalizationKey.tbmTaskDescriptionPlaceholder.localized, text: $taskDescription)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("tbm_task_description")
                    }
                    Toggle(LocalizationKey.tbmOccurredAt.localized, isOn: $hasOccurredAt)
                    if hasOccurredAt {
                        DatePicker(LocalizationKey.tbmOccurredAt.localized,
                                   selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                    HStack {
                        Text(LocalizationKey.tbmLocation.localized)
                        Spacer()
                        TextField(LocalizationKey.tbmLocationPlaceholder.localized, text: $location)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    sitePicker
                }

                Section(LocalizationKey.tbmProfile.localized) {
                    profilePicker
                }

                Section(LocalizationKey.tbmLinkedAssessment.localized) {
                    linkedAssessmentPicker
                }
            }
            .navigationTitle(LocalizationKey.tbmNew.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonSave.localized) { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("tbm_save")
                }
            }
            .alert(LocalizationKey.raSaveFailedTitle.localized, isPresented: $showSaveError) {
                Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
            } message: {
                Text(LocalizationKey.tbmSaveFailedMessage.localized)
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
                Text(LocalizationKey.tbmSite.localized).foregroundStyle(.primary)
                Spacer()
                Text(selectedSite?.name ?? LocalizationKey.tbmSiteNone.localized)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .accessibilityIdentifier("tbm_site_picker")
    }

    private var profilePicker: some View {
        Picker(LocalizationKey.tbmProfile.localized, selection: $briefingProfile) {
            Text(LocalizationKey.tbmProfileNotSet.localized).tag(BriefingProfileCode?.none)
            ForEach(BriefingProfileCode.allCases) { p in
                Text(p.localizedLabel).tag(BriefingProfileCode?.some(p))
            }
        }
        .accessibilityIdentifier("tbm_profile_picker")
    }

    private var linkedAssessmentPicker: some View {
        Menu {
            Button(LocalizationKey.tbmLinkedAssessmentNone.localized) { linkedAssessment = nil }
            ForEach(assessments) { assessment in
                Button(assessmentLabel(assessment)) { linkedAssessment = assessment }
            }
        } label: {
            HStack {
                Text(LocalizationKey.tbmLinkedAssessment.localized).foregroundStyle(.primary)
                Spacer()
                Text(linkedAssessment.map(assessmentLabel) ?? LocalizationKey.tbmLinkedAssessmentNone.localized)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .accessibilityIdentifier("tbm_assessment_picker")
    }

    private func assessmentLabel(_ assessment: RiskAssessment) -> String {
        assessment.siteName.isEmpty ? assessment.method.localizedLabel
                                     : "\(assessment.siteName) · \(assessment.method.localizedLabel)"
    }

    /// 단일 원자 Core 연산으로 저장한다 — 검증·insert·commit 이 한 번에 끝나고, 실패하면 store 와
    /// 메모리 어디에도 브리핑이 남지 않는다(`BriefingAuthoring.create`). 결과는 항상 `.draft`.
    private func save() {
        guard let site = selectedSite else { showSaveError = true; return }
        let draft = BriefingDraft(
            siteId: site.id,
            siteName: site.name,
            assessmentId: linkedAssessment?.id,
            briefingProfile: briefingProfile,
            taskDescription: taskDescription,
            occurredAt: hasOccurredAt ? occurredAt : nil,
            location: location)
        do {
            try BriefingAuthoring.create(draft, in: modelContext)
            dismiss()
        } catch {
            showSaveError = true
        }
    }
}
