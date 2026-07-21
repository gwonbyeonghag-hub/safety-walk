import Foundation
import SwiftData

/// TBM 브리핑 참여자 (SCHEMA_V3 §4). Owned by the briefing; immutable once finalized. Uses
/// only the 공유 confirmation vocabulary (순회/면담/설문은 재사용 안 함). `confirmationMethod`/
/// `confirmedAt` optional — **nil=미확인**(교정 #3). CloudKit-ready.
///
/// The initializer is deliberately **not** `public` (WO LEGAL-TBM-1 §4 "sealed로 Core 우회 불가",
/// same pattern as `CorrectiveAction`/`SharingEvent`): outside the package a `BriefingParticipant`
/// can only come from `BriefingParticipantEditing.add`, the single validated + atomic create gate.
@Model
public final class BriefingParticipant {
    public var id: UUID = UUID()
    public var name: String = ""              // 이름 필수(validate)
    public var employeeId: String?
    public var affiliation: String?
    public var jobTitle: String?
    public var role: ParticipantRole = ParticipantRole.worker
    public var confirmationMethod: ConfirmationMethod?  // nil=미확인
    public var confirmedAt: Date?
    @Attribute(.externalStorage) public var signatureData: Data?
    public var signedAt: Date?
    // CloudKit-required inverse of SafetyBriefing.participants.
    public var briefing: SafetyBriefing?

    /// SCHEMA_V3 §4.1 생성자 계약: name·role are REQUIRED. `validate()` rejects a blank name.
    init(
        name: String,
        role: ParticipantRole,
        employeeId: String? = nil,
        affiliation: String? = nil,
        jobTitle: String? = nil,
        confirmationMethod: ConfirmationMethod? = nil,
        confirmedAt: Date? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.role = role
        self.employeeId = employeeId
        self.affiliation = affiliation
        self.jobTitle = jobTitle
        self.confirmationMethod = confirmationMethod
        self.confirmedAt = confirmedAt
    }

    public func validate() throws {
        guard !name.sw_isBlank else { throw ModelValidationError.emptyName }
    }
}
