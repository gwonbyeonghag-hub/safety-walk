import Foundation
import SwiftUI
import UIKit

/// Renders an inspection report to UIImage / (future) PDF for sharing.
///
/// `InspectionReportView` performs no async work and owns no `@Query` — all
/// photos are preloaded as `UIImage`s here off-main, then handed in via
/// dictionaries so the `ImageRenderer` captures the full layout in one frame.
///
/// PDF and share-sheet wiring land in Phase 4-2 / 4-3 — this service intentionally
/// exposes only `renderImage(inspection:)` for the foundation PR.
@MainActor
final class InspectionExportService {

    private let photoStorage: PhotoStorageService
    private let photoMaxDimension: CGFloat = 600
    private let reportWidth: CGFloat = InspectionReportView.pageWidth
    private let renderScale: CGFloat = 2.0

    init(photoStorage: PhotoStorageService = PhotoStorageService()) {
        self.photoStorage = photoStorage
    }

    // MARK: - Public

    /// Renders the inspection report to a UIImage. Returns nil if rendering fails.
    /// Photo preloading runs off-main; the SwiftUI render itself runs on main
    /// (required by `ImageRenderer`), but with photos already as `UIImage`s,
    /// the render is a single synchronous snapshot with no I/O.
    func renderImage(inspection: Inspection) async -> UIImage? {
        let renderer = await makeRenderer(for: inspection)
        return renderer.uiImage
    }

    /// Renders the inspection report to a single-page tall PDF written under
    /// `FileManager.default.temporaryDirectory` with a deterministic filename
    /// (`SafetyWalk-<inspection.id>.pdf`). Repeated exports for the same
    /// inspection overwrite the previous temp file. Returns the file URL on
    /// success, or `nil` if PDF context creation or rendering failed.
    ///
    /// A4-width (595pt) single tall page for MVP — content flows in one column at
    /// A4 paper width but the page height is the full content height (no per-page
    /// breaks). Mail / KakaoTalk / AirDrop / Files all accept tall single-page PDFs,
    /// and on-screen viewers scroll cleanly.
    ///
    /// TODO (P2 follow-up): true A4 multi-page pagination (595×842 per page with a
    /// repeating masthead/footer and page n/k). It needs block-level layout splitting
    /// that the single-frame `ImageRenderer` path can't express, so it is deferred to
    /// avoid mid-row slicing. Tracked in LAUNCH_CHECKLIST P1 Share/Export note.
    func exportPDF(inspection: Inspection) async -> URL? {
        let renderer = await makeRenderer(for: inspection)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SafetyWalk-\(inspection.id.uuidString).pdf")

        // Overwrite-not-append: clear any prior export for this inspection.
        // `try?` is intentional — absence is success.
        try? FileManager.default.removeItem(at: url)

        var didRender = false
        renderer.render { size, drawer in
            var box = CGRect(origin: .zero, size: size)
            guard
                let consumer = CGDataConsumer(url: url as CFURL),
                let context = CGContext(consumer: consumer, mediaBox: &box, nil)
            else { return }
            context.beginPDFPage(nil)
            drawer(context)
            context.endPDFPage()
            context.closePDF()
            didRender = true
        }

        return didRender ? url : nil
    }

    // MARK: - Shared render setup

    /// Builds an `ImageRenderer` over a fully-populated `InspectionReportView`.
    /// Shared by both `renderImage(inspection:)` and `exportPDF(inspection:)`
    /// so the photo-preload + view-construction pipeline lives in one place.
    private func makeRenderer(for inspection: Inspection) async -> ImageRenderer<InspectionReportView> {
        let (itemPhotos, hazardPhotos) = await preloadPhotos(for: inspection)
        let report = InspectionReportView(
            inspection: inspection,
            itemPhotos: itemPhotos,
            hazardPhotos: hazardPhotos
        )
        let renderer = ImageRenderer(content: report)
        renderer.scale = renderScale
        renderer.proposedSize = .init(width: reportWidth, height: nil)
        return renderer
    }

    // MARK: - Photo preload (off-main)

    /// Extracts photo paths on main (SwiftData objects must be touched here),
    /// then performs file I/O + downsampling on a detached background task.
    /// Only plain value types (UUID, String, UIImage) cross the actor boundary —
    /// no SwiftData model instances escape the main actor.
    private func preloadPhotos(
        for inspection: Inspection
    ) async -> ([UUID: UIImage], [UUID: UIImage]) {

        let itemPairs: [(UUID, String)] = inspection.items.compactMap { item in
            guard let path = item.photoPath else { return nil }
            return (item.id, path)
        }
        let hazardPairs: [(UUID, String)] = inspection.hazards.map {
            ($0.id, $0.photoPath)
        }

        let storage = photoStorage
        let maxDim = photoMaxDimension

        return await Task.detached(priority: .userInitiated) {
            var itemPhotos: [UUID: UIImage] = [:]
            for (id, path) in itemPairs {
                if let img = storage.loadDownsampled(relativePath: path, maxDimension: maxDim) {
                    itemPhotos[id] = img
                }
            }
            var hazardPhotos: [UUID: UIImage] = [:]
            for (id, path) in hazardPairs {
                if let img = storage.loadDownsampled(relativePath: path, maxDimension: maxDim) {
                    hazardPhotos[id] = img
                }
            }
            return (itemPhotos, hazardPhotos)
        }.value
    }
}
