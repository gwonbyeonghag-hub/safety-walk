import Foundation
import SafetyWalkCore
import SwiftUI
import UIKit

/// Exports an inspection as a shareable multi-page PDF. Photos are preloaded as
/// `UIImage`s off-main (SwiftData touched on main), then handed to `InspectionReport`,
/// which lays the report out as paginated blocks via the cross-platform `ReportRenderer`.
@MainActor
final class InspectionExportService {

    private let photoStorage: PhotoStorageService
    private let photoMaxDimension: CGFloat = 600

    init(photoStorage: PhotoStorageService = PhotoStorageService()) {
        self.photoStorage = photoStorage
    }

    // MARK: - Public

    /// Renders the inspection report as a true multi-page A4 PDF via the shared
    /// cross-platform `ReportRenderer` (WO-5b) — repeating masthead/footer, page n/k,
    /// category sections + evidence photos + hazards + disclaimer, no row slicing.
    /// Photos are preloaded off-main, then handed to the (main-actor) report builder.
    func exportPDF(inspection: Inspection) async -> URL? {
        let (itemPhotos, hazardPhotos) = await preloadPhotos(for: inspection)
        return InspectionReport.pdfURL(
            inspection: inspection,
            itemPhotos: itemPhotos,
            hazardPhotos: hazardPhotos
        )
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
