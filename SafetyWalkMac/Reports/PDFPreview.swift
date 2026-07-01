import SwiftUI
import PDFKit

/// PDFKit preview of a generated report (multi-page scroll). Cross-platform engine output
/// (a real PDF file) shown in the native macOS viewer.
struct PDFPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .windowBackgroundColor
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
            view.go(to: PDFDestination(page: view.document?.page(at: 0) ?? PDFPage(), at: .zero))
        }
    }
}

enum ReportPrinter {
    /// Prints a generated PDF via the system print panel.
    @MainActor
    static func print(url: URL) {
        guard let document = PDFDocument(url: url) else { return }
        let info = NSPrintInfo.shared
        info.horizontalPagination = .fit
        info.verticalPagination = .fit
        if let operation = document.printOperation(for: info, scalingMode: .pageScaleDownToFit, autoRotate: true) {
            operation.showsPrintPanel = true
            operation.run()
        }
    }
}
