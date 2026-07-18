import SwiftUI
import SwiftData
import SafetyWalkCore

/// 공유 기록 작성 시트 (WO LEGAL-2d §6). 시점(사전/사후)은 진입점이 정하므로 여기서는 **표시만** 하고
/// 바꿀 수 없다. 저장은 원자적 Core op 하나를 통과하며, 실패하면 알럿만 띄우고 화면을 닫지 않는다.
struct SharingRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SharingRecordViewModel

    init(assessment: RiskAssessment, phase: SharingPhase) {
        _viewModel = State(wrappedValue: SharingRecordViewModel(assessment: assessment, phase: phase))
    }

    var body: some View {
        NavigationStack {
            Form {
                // 시점은 진입점 고정 — Picker 가 아니라 읽기 전용 행이다.
                Section {
                    HStack {
                        Text(LocalizationKey.raSharingSection.localized).foregroundStyle(.secondary)
                        Spacer()
                        SharingPhasePill(phase: viewModel.phase)
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("ra_sharing_phase_fixed")
                }

                Section {
                    Picker(LocalizationKey.raSharingMethod.localized, selection: $viewModel.method) {
                        ForEach(SharingMethod.allCases) { m in
                            Label(m.localizedLabel, systemImage: m.systemImage).tag(m)
                        }
                    }
                    .accessibilityIdentifier("ra_sharing_method_picker")

                    LabeledContent(LocalizationKey.raSharingTarget.localized) {
                        TextField(LocalizationKey.raSharingTargetPlaceholder.localized,
                                  text: $viewModel.target)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("ra_sharing_target_field")
                    }

                    LabeledContent(LocalizationKey.raSharingOwner.localized) {
                        TextField(LocalizationKey.raAssessorPlaceholder.localized,
                                  text: $viewModel.ownerName)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("ra_sharing_owner_field")
                    }
                }

                // 법적 판정이 아니라 "사용자가 한 공유를 기록한다"는 사실 고지 (CLAUDE.md No legal judgment).
                Section {
                    Text(LocalizationKey.raSharingDisclaimer.localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizationKey.commonCancel.localized) { dismiss() }
                }
                // 저장은 툴바에 — 참여자·개선조치 편집기와 같은 자리이고, 큰 글자(Dynamic Type)에서도
                // 폼과 함께 스크롤되어 사라지지 않는다.
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationKey.commonSave.localized) {
                        viewModel.save(context: modelContext) { dismiss() }
                    }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("ra_sharing_save")
                }
            }
            .alert(LocalizationKey.raSharingFailedTitle.localized,
                   isPresented: $viewModel.showSaveError) {
                Button(LocalizationKey.commonConfirm.localized, role: .cancel) { }
            } message: {
                Text(viewModel.saveErrorMessage)
            }
        }
    }
}

/// 사전/사후 표시 — 중립 색(위험도 램프를 빌리지 않는다).
struct SharingPhasePill: View {
    let phase: SharingPhase

    var body: some View {
        Text(phase.localizedLabel)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
    }
}
