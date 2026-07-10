import SwiftUI
import SafetyWalkCore

/// Reusable Share Report button used by both `InspectionSummaryView` (depth-3)
/// and `InspectionDetailView` (depth-1 when status == .completed).
/// Owns the export pipeline state — both call sites just embed this view.
///
/// - Tap → `InspectionExportService().exportPDF(inspection:)`
/// - While exporting → spinner + "Preparing report…", button disabled
/// - On success → present `ShareSheet` with the PDF URL
/// - On failure → present a localized "Could not prepare report." alert
struct ShareReportButton: View {

    let inspection: Inspection

    @Environment(ProStore.self) private var proStore

    @State private var isExporting = false
    @State private var showFailedAlert = false
    // One sheet slot (stacked `.sheet` modifiers conflict in SwiftUI): the gate routes to
    // the paywall (non-Pro) or the share sheet (Pro, after export succeeds).
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Identifiable {
        case paywall
        case share(URL)
        var id: String {
            switch self {
            case .paywall:        return "paywall"
            case .share(let url): return url.absoluteString
            }
        }
    }

    var body: some View {
        Button {
            // Gate B (WO-10): exporting/sharing a report as PDF is Pro. Non-subscribers get
            // the paywall; viewing the inspection and its report on-screen stays free.
            if proStore.isPro { Task { await share() } } else { activeSheet = .paywall }
        } label: {
            buttonLabel
        }
        .buttonStyle(.bordered)
        .disabled(isExporting)
        .accessibilityIdentifier("share_report_button")
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .paywall:        PaywallView()
            case .share(let url): ShareSheet(items: [url])
            }
        }
        .alert(LocalizationKey.shareFailed.localized,
               isPresented: $showFailedAlert) {
            Button(LocalizationKey.commonConfirm.localized) {}
        }
    }

    @ViewBuilder
    private var buttonLabel: some View {
        if isExporting {
            HStack(spacing: 8) {
                ProgressView()
                Text(LocalizationKey.shareExporting.localized)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
        } else {
            Label(LocalizationKey.shareButton.localized,
                  systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
    }

    private func share() async {
        isExporting = true
        let url = await InspectionExportService().exportPDF(inspection: inspection)
        isExporting = false
        if let url {
            activeSheet = .share(url)
        } else {
            showFailedAlert = true
        }
    }
}
