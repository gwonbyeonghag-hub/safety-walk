import Foundation
import SwiftUI
import SwiftData
import SafetyWalkCore

/// Orchestrates 공유 기록 작성 (WO LEGAL-2d §6): holds the draft fields and routes the save through
/// the atomic Core op so the View carries no persistence policy (CLAUDE.md MVVM).
///
/// `phase` is decided by the ENTRY POINT (planned → 사전, finalized → 사후) and is `let` — the user
/// can never flip 사전/사후 in this screen, because that would misdescribe what was actually shared.
/// The screen stays up on failure and only the caller's `onSaved` closure dismisses it.
@MainActor
@Observable
final class SharingRecordViewModel {

    private let assessment: RiskAssessment

    /// Fixed at construction — 진입점이 결정한다(사용자 변경 불가).
    let phase: SharingPhase

    // Editable fields
    var method: SharingMethod = .education
    var target: String = ""
    /// 공유 담당자 — 평가자 이름을 prefill 하되 실제 공유를 수행한 사람으로 수정 가능.
    var ownerName: String

    // Distinct error surfacing (LEGAL-0 패턴: 실패 시 화면 유지)
    var showSaveError = false
    private(set) var saveErrorMessage: String = LocalizationKey.raSharingFailedMessage.localized

    init(assessment: RiskAssessment, phase: SharingPhase) {
        self.assessment = assessment
        self.phase = phase
        self.ownerName = assessment.assessorName
    }

    // MARK: - Derived UI state

    /// 저장 가능 = 비공백 대상 + 비공백 담당자. Core 가 최종 관문이지만 버튼 비활성화의 단일 소스이기도 하다.
    var canSave: Bool {
        !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var title: String {
        phase == .pre ? LocalizationKey.raSharingRecordPre.localized
                      : LocalizationKey.raSharingRecordPost.localized
    }

    // MARK: - Save

    /// Records the share through the single Core create gate. Calls `onSaved` ONLY on success —
    /// a failed save must never dismiss the screen (the record would silently not exist).
    func save(context: ModelContext, now: Date = Date(), onSaved: () -> Void) {
        do {
            try SharingEventRecording.record(phase: phase, method: method, in: assessment,
                                             target: target, ownerName: ownerName,
                                             at: now, context: context)
            onSaved()
        } catch {
            saveErrorMessage = Self.message(for: error)
            showSaveError = true
        }
    }

    /// Maps the Core refusal to a localized explanation. Everything else falls back to the generic
    /// save-failure message — the app never invents a legal-sounding reason.
    private static func message(for error: Error) -> String {
        guard let recordError = error as? SharingRecordError else {
            return LocalizationKey.raSharingFailedMessage.localized
        }
        switch recordError {
        case .emptyTarget:      return LocalizationKey.raSharingTargetRequired.localized
        case .emptyOwner:       return LocalizationKey.raSharingOwnerRequired.localized
        case .missingSchedule:  return LocalizationKey.raSharingScheduleMissing.localized
        case .phaseNotAllowed, .snapshotFailed:
            return LocalizationKey.raSharingFailedMessage.localized
        }
    }
}
