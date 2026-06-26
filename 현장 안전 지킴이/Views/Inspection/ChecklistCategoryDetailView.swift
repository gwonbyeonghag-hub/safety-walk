import SwiftUI
import SafetyWalkCore

struct ChecklistCategoryDetailView: View {

    let inspection: Inspection
    let categoryKey: String
    let items: [ChecklistItem]

    var body: some View {
        List {
            ForEach(items) { item in
                ChecklistItemRow(item: item, inspection: inspection)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L(categoryKey))
        .navigationBarTitleDisplayMode(.inline)
    }
}
