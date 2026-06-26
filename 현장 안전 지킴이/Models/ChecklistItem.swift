import Foundation
import SwiftData

@Model
final class ChecklistItem {
    var id: UUID
    var inspectionId: UUID
    var templateItemId: String
    // Title and category are copied from the template at inspection creation time
    // so the record stays valid even if the template changes later
    var title: String
    var category: String
    var result: ChecklistItemResult
    var note: String?
    var photoPath: String?
    var linkedHazardId: UUID?
    var sortOrder: Int

    init(
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
