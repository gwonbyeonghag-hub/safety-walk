import Foundation
import SwiftData

@Model
public final class Hazard {
    public var id: UUID
    public var inspectionId: UUID?
    public var siteId: UUID
    public var location: String
    public var type: HazardType
    public var riskLevel: RiskLevel
    // Named hazardDescription to avoid shadowing CustomStringConvertible.description
    public var hazardDescription: String
    public var photoPath: String
    public var correctiveActionStatus: CorrectiveActionStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        siteId: UUID,
        location: String,
        type: HazardType,
        riskLevel: RiskLevel,
        hazardDescription: String,
        photoPath: String,
        inspectionId: UUID? = nil
    ) {
        self.id = UUID()
        self.siteId = siteId
        self.location = location
        self.type = type
        self.riskLevel = riskLevel
        self.hazardDescription = hazardDescription
        self.photoPath = photoPath
        self.correctiveActionStatus = .notStarted
        self.createdAt = Date()
        self.updatedAt = Date()
        self.inspectionId = inspectionId
    }
}
