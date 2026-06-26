import SwiftUI

// Typed navigation path values for the 3-step flow.
// Using NavigationStack(path:) with a typed enum avoids the conditional-content
// type instability that occurs when navigationDestination(isPresented:) closures
// contain if-let branches that evaluate to EmptyView on first render.
enum FlowStep: Hashable {
    case area(UUID)   // carries the selected site's id for AreaSelectionView's @Query
    case template
    case scope        // category/scope selection — operates on viewModel.selectedTemplate
}

/// Sheet root for the Start Inspection flow.
/// All navigationDestination registrations live here so the path is the single
/// source of truth for which step is visible.
struct StartInspectionFlow: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = StartInspectionViewModel()
    @State private var path: [FlowStep] = []
    @State private var isDone = false

    var body: some View {
        NavigationStack(path: $path) {
            SiteSelectionView(isDone: $isDone, path: $path)
                .navigationDestination(for: FlowStep.self) { step in
                    switch step {
                    case .area(let siteId):
                        AreaSelectionView(isDone: $isDone, siteId: siteId, path: $path)
                    case .template:
                        TemplateSelectionView(isDone: $isDone, path: $path)
                    case .scope:
                        InspectionScopeSelectionView(isDone: $isDone)
                    }
                }
        }
        .environment(viewModel)
        .onChange(of: isDone) { _, done in
            if done { dismiss() }
        }
    }
}
