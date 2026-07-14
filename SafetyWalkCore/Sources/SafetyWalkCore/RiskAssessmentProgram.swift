import Foundation
import SwiftData

/// 현장별 위험성평가 프로그램 (SCHEMA_V3 §4). Physical delete is never used — a retired
/// program is `archived` with `archivedAt` set (교정 #1·#5). Links to Site by UUID + value
/// snapshot (관계 아님 → cascade 없음), so archiving/deleting a Site never wipes program
/// history. CloudKit-ready: attributes optional or defaulted, no `.unique`.
@Model
public final class RiskAssessmentProgram {
    public var id: UUID = UUID()
    public var siteId: UUID?
    public var siteName: String = ""                 // 참조 + 값 스냅샷
    public var jurisdiction: JurisdictionCode?       // 법규 프로필 코드(교정 #6)
    public var industryProfile: IndustryProfileCode?
    public var profileVersion: Int = 1
    public var effectiveFrom: Date?
    public var effectiveTo: Date?
    public var operatingMode: OperatingMode = OperatingMode.regular
    public var status: ProgramStatus = ProgramStatus.active
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var archivedAt: Date?                      // archived 시각(교정 #5)

    /// SCHEMA_V3 §4.1 생성자 계약: siteId·siteName·jurisdiction are REQUIRED.
    public init(
        siteId: UUID,
        siteName: String,
        jurisdiction: JurisdictionCode,
        industryProfile: IndustryProfileCode? = nil,
        profileVersion: Int = 1,
        effectiveFrom: Date? = nil,
        effectiveTo: Date? = nil,
        operatingMode: OperatingMode = .regular
    ) {
        self.id = UUID()
        self.siteId = siteId
        self.siteName = siteName
        self.jurisdiction = jurisdiction
        self.industryProfile = industryProfile
        self.profileVersion = profileVersion
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
        self.operatingMode = operatingMode
        self.status = .active
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public func validate() throws {
        guard siteId != nil else { throw ModelValidationError.missingSite }
        guard !siteName.sw_isBlank else { throw ModelValidationError.emptySiteName }
        guard jurisdiction != nil else { throw ModelValidationError.missingJurisdiction }
    }
}
