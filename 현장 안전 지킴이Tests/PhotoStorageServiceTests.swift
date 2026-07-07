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

// MARK: - data(from:)

@Suite("PhotoStorageService — data(from:)")
struct PhotoStorageServiceDataTests {

    @Test func producesNonEmptyJPEGData() throws {
        let service = PhotoStorageService()
        let data = try service.data(from: makeImage(width: 100, height: 100))

        #expect(!data.isEmpty, "Compressed photo data should not be empty.")
    }

    @Test func producesDecodableImage() throws {
        let service = PhotoStorageService()
        let data = try service.data(from: makeImage(width: 100, height: 100))

        #expect(UIImage(data: data) != nil, "Compressed data should decode back into an image.")
    }
}

// MARK: - Legacy file access (pre-WO-3 photoPath scheme; migration-only)

@Suite("PhotoStorageService — legacy file access")
struct PhotoStorageServiceLegacyTests {

    private func writeLegacyFile(in tmpDir: URL, relativePath: String, bytes: Data) throws {
        let url = tmpDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url)
    }

    @Test func loadLegacyDataReturnsBytesForExistingFile() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }
        let bytes = Data("legacy-photo".utf8)
        try writeLegacyFile(in: tmpDir, relativePath: "EvidencePhotos/a.jpg", bytes: bytes)

        let service = PhotoStorageService(rootDirectory: tmpDir)
        #expect(service.loadLegacyData(relativePath: "EvidencePhotos/a.jpg") == bytes)
    }

    @Test func loadLegacyDataReturnsNilForMissingFile() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        #expect(service.loadLegacyData(relativePath: "EvidencePhotos/does-not-exist.jpg") == nil)
    }

    @Test func deleteLegacyFileRemovesFileFromDisk() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }
        try writeLegacyFile(in: tmpDir, relativePath: "EvidencePhotos/a.jpg", bytes: Data("x".utf8))
        let fileURL = tmpDir.appendingPathComponent("EvidencePhotos/a.jpg")

        let service = PhotoStorageService(rootDirectory: tmpDir)
        try service.deleteLegacyFile(relativePath: "EvidencePhotos/a.jpg")

        #expect(!FileManager.default.fileExists(atPath: fileURL.path),
                "File should no longer exist after deleteLegacyFile().")
    }

    @Test func deleteLegacyFileNonexistentPathDoesNotThrow() throws {
        let (tmpDir, cleanup) = try makeTempDirectory()
        defer { cleanup() }

        let service = PhotoStorageService(rootDirectory: tmpDir)
        // Must not throw — silently succeeds when the file is already gone
        try service.deleteLegacyFile(relativePath: "EvidencePhotos/does-not-exist.jpg")
    }
}

// MARK: - Resize

@Suite("PhotoStorageService — resize")
struct PhotoStorageServiceResizeTests {

    // Large landscape image: longest side 2048px → must be ≤ 1024px after compression.
    @Test func largeImageIsResizedToAtMost1024Pixels() throws {
        let service = PhotoStorageService()
        let data = try service.data(from: makeImage(width: 2048, height: 1536))

        let decoded = try #require(UIImage(data: data), "Expected a decodable image.")
        let longestSide = max(decoded.size.width, decoded.size.height)

        #expect(longestSide <= 1024,
                "Longest side should be ≤ 1024px after resize; got \(longestSide)px.")
    }

    // Large portrait image: longest side 1536px → must be ≤ 1024px after compression.
    @Test func largePortraitImageIsResized() throws {
        let service = PhotoStorageService()
        let data = try service.data(from: makeImage(width: 768, height: 1536))

        let decoded = try #require(UIImage(data: data))
        let longestSide = max(decoded.size.width, decoded.size.height)

        #expect(longestSide <= 1024,
                "Longest side should be ≤ 1024px after resize; got \(longestSide)px.")
    }

    // Small image: 200×150 → must NOT be upscaled; longest side stays at 200px.
    @Test func smallImageIsNotUpscaled() throws {
        let service = PhotoStorageService()
        let data = try service.data(from: makeImage(width: 200, height: 150))

        let decoded = try #require(UIImage(data: data))
        let longestSide = max(decoded.size.width, decoded.size.height)

        #expect(longestSide <= 200,
                "Small image (200×150) must not be upscaled; longest side was \(longestSide)px.")
    }

    // Image whose longest side is exactly 1024px → must not be resized.
    @Test func imageAtExactly1024pxIsNotResized() throws {
        let service = PhotoStorageService()
        let data = try service.data(from: makeImage(width: 1024, height: 768))

        let decoded = try #require(UIImage(data: data))
        let longestSide = max(decoded.size.width, decoded.size.height)

        #expect(longestSide <= 1024,
                "Image at exactly 1024px must not be upscaled; longest side was \(longestSide)px.")
    }
}

// MARK: - downsampled(_:maxDimension:)

@Suite("PhotoStorageService — downsampled")
struct PhotoStorageServiceDownsampledTests {

    @Test func downsampledDecodesToAtMostMaxDimension() throws {
        let service = PhotoStorageService()
        let data = try service.data(from: makeImage(width: 2048, height: 1536))

        let thumb = try #require(PhotoStorageService.downsampled(data, maxDimension: 300))
        let longestSide = max(thumb.size.width, thumb.size.height)

        #expect(longestSide <= 300, "Downsampled thumbnail should be ≤ 300px; got \(longestSide)px.")
    }

    @Test func downsampledReturnsNilForGarbageData() {
        let result = PhotoStorageService.downsampled(Data("not-an-image".utf8), maxDimension: 300)
        #expect(result == nil)
    }
}
