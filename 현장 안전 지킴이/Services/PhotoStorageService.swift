import Foundation
import UIKit
import ImageIO

// MARK: - Error

enum PhotoStorageError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image as JPEG."
        }
    }
}

// MARK: - Service

/// Compresses evidence photos into `Data` for storage in `ChecklistItem.photoData` /
/// `Hazard.photoData` (`@Attribute(.externalStorage)`, CloudKit-synced as a CKAsset).
/// Also provides read/delete access to the pre-WO-3 file-based photo scheme
/// (Documents/EvidencePhotos/<uuid>.jpg) for the one-time schema migration only.
/// Inject a custom rootDirectory in unit tests to avoid touching the real Documents folder.
struct PhotoStorageService {

    nonisolated static let folderName = "EvidencePhotos"

    nonisolated private static let maxLongSidePx: CGFloat = 1024
    nonisolated private static let jpegQuality: CGFloat = 0.82

    let rootDirectory: URL

    // Project target uses SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, which would make
    // this initializer MainActor-isolated by default. Marking it nonisolated lets
    // `InspectionExportService.preloadPhotos` (and any other off-main caller) use
    // `PhotoStorageService` without crossing the actor boundary at construction.
    nonisolated init(rootDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.rootDirectory = rootDirectory
    }

    // MARK: - Public API

    /// Resizes to ≤1024px on the longest side and compresses as JPEG. The result is
    /// stored directly in the model's `photoData` field — no file written to disk.
    nonisolated func data(from image: UIImage) throws -> Data {
        let resized = Self.resized(image, maxLongSide: Self.maxLongSidePx)
        guard let data = resized.jpegData(compressionQuality: Self.jpegQuality) else {
            throw PhotoStorageError.compressionFailed
        }
        return data
    }

    /// Loads a memory-efficient thumbnail from already-in-memory photo `data`, downsampled
    /// so the longer side is no larger than `maxDimension` (in pixels). Uses `ImageIO` so the
    /// full-resolution image is never decoded into memory — important for export rendering
    /// where many photos must be loaded at once. Returns nil if `data` cannot be decoded.
    nonisolated static func downsampled(_ data: Data, maxDimension: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Legacy file-based photos (pre-WO-3; migration-only)

    /// Reads the raw bytes at a legacy relative path written by the old file-based
    /// save(). Used only by the ChecklistItem/Hazard schema migration to carry existing
    /// photos into `photoData`.
    nonisolated func loadLegacyData(relativePath: String) -> Data? {
        let url = rootDirectory.appendingPathComponent(relativePath)
        return FileManager.default.contents(atPath: url.path)
    }

    /// Deletes the legacy file at the given relative path once migrated.
    /// Succeeds silently if the file does not exist.
    nonisolated func deleteLegacyFile(relativePath: String) throws {
        let url = rootDirectory.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// Removes every file inside the EvidencePhotos folder. Best-effort cleanup of any
    /// legacy files left behind; normal operation no longer writes here.
    /// Succeeds silently if the folder does not exist.
    nonisolated func deleteAllEvidencePhotos() throws {
        let folder = rootDirectory.appendingPathComponent(Self.folderName)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        let contents = try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil)
        for file in contents {
            try FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Private helpers

    nonisolated private static func resized(_ image: UIImage, maxLongSide: CGFloat) -> UIImage {
        let size = image.size
        let longSide = max(size.width, size.height)
        guard longSide > maxLongSide else { return image }
        let scale = maxLongSide / longSide
        let newSize = CGSize(
            width: (size.width * scale).rounded(),
            height: (size.height * scale).rounded()
        )
        // scale = 1.0: output pixel dimensions == newSize, not newSize × displayScale.
        // Camera images have scale=1.0 and large pixel dimensions; we want the JPEG to
        // be ≤ maxLongSide pixels, not ≤ maxLongSide points at device display scale.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
