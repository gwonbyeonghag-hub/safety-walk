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

    @State private var isExporting = false
    @State private var shareItem: ShareItem?
    @State private var showFailedAlert = false

    var body: some View {
        Button {
            Task { await share() }
        } label: {
            buttonLabel
        }
        .buttonStyle(.bordered)
        .disabled(isExporting)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
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
            shareItem = ShareItem(url: url)
        } else {
            showFailedAlert = true
        }
    }
}
