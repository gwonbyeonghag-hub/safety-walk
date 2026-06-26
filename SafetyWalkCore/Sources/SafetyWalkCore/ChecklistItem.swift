import Foundation
import SwiftData

@Model
public final class ChecklistItem {
    public var id: UUID
    public var inspectionId: UUID
    public var templateItemId: String
    // Title and category are copied from the template at inspection creation time
    // so the record stays valid even if the template changes later
    public var title: String
    public var category: String
    public var result: ChecklistItemResult
    public var note: String?
    public var photoPath: String?
    public var linkedHazardId: UUID?
    public var sortOrder: Int

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
