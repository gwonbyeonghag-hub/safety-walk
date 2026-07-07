import Foundation
import SwiftData

@Model
public final class Hazard {
    public var id: UUID = UUID()
    public var inspectionId: UUID?
    public var siteId: UUID = UUID()
    public var location: String = ""
    public var type: HazardType = HazardType.general
    public var riskLevel: RiskLevel = RiskLevel.low
    // Named hazardDescription to avoid shadowing CustomStringConvertible.description
    public var hazardDescription: String = ""
    // CloudKit-synced as a CKAsset (WO-3); replaces the file-path-based photoPath.
    // nil means "no photo" (photoPath's old "" sentinel is gone).
    @Attribute(.externalStorage) public var photoData: Data?
    public var correctiveActionStatus: CorrectiveActionStatus = CorrectiveActionStatus.notStarted
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    // CloudKit-required inverse of Inspection.hazards. Not read by app code —
    // `inspectionId` above remains the source of truth for lookups, and standalone
    // hazards (inspectionId == nil) correctly keep this nil too (§5 standalone rule).
    public var inspection: Inspection?

    public init(
        siteId: UUID,
        location: String,
        type: HazardType,
        riskLevel: RiskLevel,
        hazardDescription: String,
        photoData: Data? = nil,
        inspectionId: UUID? = nil
    ) {
        self.id = UUID()
        self.siteId = siteId
        self.location = location
        self.type = type
        self.riskLevel = riskLevel
        self.hazardDescription = hazardDescription
        self.photoData = photoData
        self.correctiveActionStatus = .notStarted
        self.createdAt = Date()
        self.updatedAt = Date()
        self.inspectionId = inspectionId
    }
}
