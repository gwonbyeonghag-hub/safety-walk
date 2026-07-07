import Foundation
import SwiftData

@Model
public final class ChecklistItem {
    public var id: UUID = UUID()
    public var inspectionId: UUID = UUID()
    public var templateItemId: String = ""
    // Title and category are copied from the template at inspection creation time
    // so the record stays valid even if the template changes later
    public var title: String = ""
    public var category: String = ""
    public var result: ChecklistItemResult = ChecklistItemResult.unchecked
    public var note: String?
    // CloudKit-synced as a CKAsset (WO-3); replaces the file-path-based photoPath.
    @Attribute(.externalStorage) public var photoData: Data?
    public var linkedHazardId: UUID?
    public var sortOrder: Int = 0
    // CloudKit-required inverse of Inspection.items. Not read by app code —
    // `inspectionId` above remains the source of truth for lookups.
    public var inspection: Inspection?

    public init(
        inspectionId: UUID,
        templateItemId: String,
        title: String,
        category: String,
        sortOrder: Int
    ) {
        self.id = UUID()
        self.inspectionId = inspectionId
        self.templateItemId = templateItemId
        self.title = title
        self.category = category
        self.result = .unchecked
        self.sortOrder = sortOrder
    }
}
