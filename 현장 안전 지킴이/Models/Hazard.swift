import Foundation
import SwiftData

@Model
final class Hazard {
    var id: UUID
    var inspectionId: UUID?
    var siteId: UUID
    var location: String
    var type: HazardType
    var riskLevel: RiskLevel
    // Named hazardDescription to avoid shadowing CustomStringConvertible.description
    var hazardDescription: String
    var photoPath: String
    var correctiveActionStatus: CorrectiveActionStatus
    var createdAt: Date
    var updatedAt: Date

    init(
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
