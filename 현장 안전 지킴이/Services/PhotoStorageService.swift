import Foundation
import UIKit
import ImageIO

// MARK: - Error

enum PhotoStorageError: LocalizedError {
    case compressionFailed
    case saveFailed(underlying: Error)
    case folderCreationFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image as JPEG."
        case .saveFailed(let error):
            return "Failed to save photo: \(error.localizedDescription)"
        case .folderCreationFailed(let error):
            return "Failed to create photo storage folder: \(error.localizedDescription)"
        }
    }
}

// MARK: - Service

/// Saves, loads, and deletes evidence photos in Documents/EvidencePhotos/.
/// Paths returned by save() are relative to the Documents directory so they
/// remain valid across device restores and app updates.
/// Inject a custom rootDirectory in unit tests to avoid writing to the real Documents folder.
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

    /// Resizes to ≤1024px on the longest side, compresses as JPEG, saves under
    /// EvidencePhotos/ with a UUID filename, and returns the relative path.
    nonisolated func save(_ image: UIImage) throws -> String {
        let resized = Self.resized(image, maxLongSide: Self.maxLongSidePx)
        guard let data = resized.jpegData(compressionQuality: Self.jpegQuality) else {
            throw PhotoStorageError.compressionFailed
        }
        let folder = try ensureFolder()
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = folder.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw PhotoStorageError.saveFailed(underlying: error)
        }
        return "\(Self.folderName)/\(filename)"
    }

    /// Loads a UIImage from a relative path previously returned by save().
    /// Returns nil if the file does not exist or cannot be decoded.
    nonisolated func load(relativePath: String) -> UIImage? {
        let url = rootDirectory.appendingPathComponent(relativePath)
        return UIImage(contentsOfFile: url.path)
    }

    /// Loads a memory-efficient thumbnail of the photo at `relativePath`, downsampled so
    /// the longer side is no larger than `maxDimension` (in pixels). Uses `ImageIO` so the
    /// full-resolution image is never decoded into memory — important for export rendering
    /// where many photos must be loaded at once.
    /// Returns nil if the file is missing or cannot be decoded.
    nonisolated func loadDownsampled(relativePath: String, maxDimension: CGFloat) -> UIImage? {
        let url = rootDirectory.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Deletes the file at the given relative path.
    /// Succeeds silently if the file does not exist.
    nonisolated func delete(relativePath: String) throws {
        let url = rootDirectory.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// Removes every file inside the EvidencePhotos folder.
    /// Succeeds silently if the folder does not exist.
    /// The folder itself is preserved so future saves do not need to recreate it.
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

    nonisolated private func ensureFolder() throws -> URL {
        let folder = rootDirectory.appendingPathComponent(Self.folderName)
        guard !FileManager.default.fileExists(atPath: folder.path) else { return folder }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw PhotoStorageError.folderCreationFailed(underlying: error)
        }
        return folder
    }

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
