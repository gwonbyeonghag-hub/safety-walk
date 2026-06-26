import Testing
import Foundation
import UIKit
@testable import 현장_안전_지킴이

// MARK: - Helpers

private func makeTempDirectory() throws -> (URL, cleanup: () -> Void) {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("PhotoStorageTest-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return (url, { try? FileManager.default.removeItem(at: url) })
}

/// Creates a solid-color image with exact pixel dimensions (scale=1.0).
/// scale=1.0 ensures size.width/height == pixel width/height, making
/// resize assertions deterministic across all simulator and device scales.
private func makeImage(width: Int, height: Int, color: UIColor = .red) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(
        size: CGSize(width: width, height: height),
        format: format
    )
    return renderer.image { ctx in
        color.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

// MARK: - Save

@Suite("PhotoStorageService — save")
struct PhotoStorageServiceSaveTests {

    @Test func saveReturnsPathWithEvidencePhotosPrefix() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 100, height: 100))

        #expect(path.hasPrefix("EvidencePhotos/"),
                "Returned path '\(path)' must start with 'EvidencePhotos/'")
    }

    @Test func savePathHasJpgExtension() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 100, height: 100))

        #expect(path.hasSuffix(".jpg"),
                "Returned path '\(path)' must end with '.jpg'")
    }

    @Test func saveCreatesFileAtExpectedPath() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 100, height: 100))

        let fileURL = tmpDir.appendingPathComponent(path)
        #expect(FileManager.default.fileExists(atPath: fileURL.path),
                "Expected file at \(fileURL.path) but it was not found.")
    }

    @Test func savedFileHasNonZeroSize() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 100, height: 100))

        let fileURL = tmpDir.appendingPathComponent(path)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let byteCount = attributes[.size] as? Int ?? 0
        #expect(byteCount > 0, "Saved file should not be empty.")
    }

    @Test func consecutiveSavesProduceDifferentPaths() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path1 = try service.save(makeImage(width: 100, height: 100))
        let path2 = try service.save(makeImage(width: 100, height: 100))

        #expect(path1 != path2, "Each save must produce a unique path.")
    }
}

// MARK: - Load

@Suite("PhotoStorageService — load")
struct PhotoStorageServiceLoadTests {

    @Test func loadReturnsSavedImage() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 200, height: 150))

        let loaded = service.load(relativePath: path)

        #expect(loaded != nil, "load() should return a UIImage for a path that was just saved.")
    }

    @Test func loadReturnsNilForNonexistentPath() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let result = service.load(relativePath: "EvidencePhotos/does-not-exist.jpg")

        #expect(result == nil, "load() should return nil for a path that was never saved.")
    }
}

// MARK: - Delete

@Suite("PhotoStorageService — delete")
struct PhotoStorageServiceDeleteTests {

    @Test func deleteRemovesFileFromDisk() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 100, height: 100))
        let fileURL = tmpDir.appendingPathComponent(path)

        try service.delete(relativePath: path)

        #expect(!FileManager.default.fileExists(atPath: fileURL.path),
                "File should no longer exist after delete().")
    }

    @Test func deleteNonexistentPathDoesNotThrow() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)

        // Must not throw — silently succeeds when the file is already gone
        try service.delete(relativePath: "EvidencePhotos/does-not-exist.jpg")
    }

    @Test func loadReturnsNilAfterDelete() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 100, height: 100))

        try service.delete(relativePath: path)

        #expect(service.load(relativePath: path) == nil,
                "load() should return nil after the file has been deleted.")
    }
}

// MARK: - Resize

@Suite("PhotoStorageService — resize")
struct PhotoStorageServiceResizeTests {

    // Large landscape image: longest side 2048px → must be ≤ 1024px after save/load.
    @Test func largeImageIsResizedToAtMost1024Pixels() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 2048, height: 1536))

        let loaded = try #require(service.load(relativePath: path),
                                  "Expected a loadable image after save.")
        let longestSide = max(loaded.size.width, loaded.size.height)

        #expect(longestSide <= 1024,
                "Longest side should be ≤ 1024px after resize; got \(longestSide)px.")
    }

    // Large portrait image: longest side 1536px → must be ≤ 1024px after save/load.
    @Test func largePortraitImageIsResized() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 768, height: 1536))

        let loaded = try #require(service.load(relativePath: path))
        let longestSide = max(loaded.size.width, loaded.size.height)

        #expect(longestSide <= 1024,
                "Longest side should be ≤ 1024px after resize; got \(longestSide)px.")
    }

    // Small image: 200×150 → must NOT be upscaled; longest side stays at 200px.
    @Test func smallImageIsNotUpscaled() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 200, height: 150))

        let loaded = try #require(service.load(relativePath: path))
        let longestSide = max(loaded.size.width, loaded.size.height)

        #expect(longestSide <= 200,
                "Small image (200×150) must not be upscaled; longest side was \(longestSide)px.")
    }

    // Image whose longest side is exactly 1024px → must not be resized.
    @Test func imageAtExactly1024pxIsNotResized() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        let path = try service.save(makeImage(width: 1024, height: 768))

        let loaded = try #require(service.load(relativePath: path))
        let longestSide = max(loaded.size.width, loaded.size.height)

        #expect(longestSide <= 1024,
                "Image at exactly 1024px must not be upscaled; longest side was \(longestSide)px.")
    }
}
