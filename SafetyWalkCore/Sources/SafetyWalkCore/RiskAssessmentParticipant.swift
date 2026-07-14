import Foundation
import SwiftData

/// 위험성평가 참여자 (SCHEMA_V3 §4). Owned by the assessment; immutable once finalized.
/// `participationMethod`/`confirmationMethod`/`confirmedAt` are optional — **nil=미기록**
/// (교정 #3). `participationMethod` uses the assessment-only 순회/면담/설문/기타 vocabulary.
/// CloudKit-ready: attributes optional or defaulted, binary via externalStorage, no `.unique`.
@Model
public final class RiskAssessmentParticipant {
    public var id: UUID = UUID()
    public var name: String = ""              // 이름 필수(validate)
    public var employeeId: String?
    public var affiliation: String?
    public var jobTitle: String?
    public var role: ParticipantRole = ParticipantRole.worker
    public var participationMethod: AssessmentParticipationMethod?  // nil=미기록(평가 전용)
    public var participatedAt: Date?
    public var confirmationMethod: ConfirmationMethod?              // nil=미확인(교정 #3)
    public var confirmedAt: Date?
    @Attribute(.externalStorage) public var signatureData: Data?
    public var signedAt: Date?
    // CloudKit-required inverse of RiskAssessment.participants.
    public var riskAssessment: RiskAssessment?

    /// SCHEMA_V3 §4.1 생성자 계약: name·role are REQUIRED. `validate()` rejects a blank name.
    public init(
        name: String,
        role: ParticipantRole,
        employeeId: String? = nil,
        affiliation: String? = nil,
        jobTitle: String? = nil,
        participationMethod: AssessmentParticipationMethod? = nil,
        participatedAt: Date? = nil,
        confirmationMethod: ConfirmationMethod? = nil,
        confirmedAt: Date? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.role = role
        self.employeeId = employeeId
        self.affiliation = affiliation
        self.jobTitle = jobTitle
        self.participationMethod = participationMethod
        self.participatedAt = participatedAt
        self.confirmationMethod = confirmationMethod
        self.confirmedAt = confirmedAt
    }

    public func validate() throws {
        guard !name.sw_isBlank else { throw ModelValidationError.emptyName }
    }
}
