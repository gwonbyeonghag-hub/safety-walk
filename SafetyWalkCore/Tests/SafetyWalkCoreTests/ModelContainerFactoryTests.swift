import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO-9: the shared ModelContainer factory must never fatalError on a bad on-disk store.
// When the store can't be opened it moves the store aside (preserved, never deleted),
// retries fresh, and — only as a last resort — falls back to in-memory. These tests drive
// the recovery seam with a plain on-disk configuration (no CloudKit / no entitlements),
// which is exactly what SwiftPM can run headlessly.
struct ModelContainerFactoryTests {

    private static let schema = Schema(versionedSchema: SchemaV2.self)

    private func uniqueStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("wo9-\(UUID().uuidString).store")
    }

    /// A store the migration/open step can't read must not crash the app: it is moved aside
    /// (original bytes preserved under a `.bak`) and a working, fresh container is returned.
    @Test func recoversFromUnopenableStore() throws {
        let fm = FileManager.default
        let storeURL = uniqueStoreURL()
        let sentinel = Data("not-a-sqlite-store".utf8)
        try sentinel.write(to: storeURL)

        let container = SafetyWalkModelContainer.makeRecoverable(
            schema: Self.schema,
            migrationPlan: nil,
            storeURL: storeURL,
            backupSuffix: "wo9test"
        ) {
            ModelConfiguration(schema: Self.schema, url: storeURL)
        }

        // 1) A usable container came back — insert + fetch round-trips.
        let ctx = ModelContext(container)
        ctx.insert(Site(name: "복구 후 현장"))
        try ctx.save()
        let sites = try ctx.fetch(FetchDescriptor<Site>())
        #expect(sites.count == 1)

        // 2) The original store was MOVED aside, not deleted — bytes preserved verbatim.
        let backupURL = URL(fileURLWithPath: storeURL.path + ".wo9test.bak")
        #expect(fm.fileExists(atPath: backupURL.path))
        #expect(try Data(contentsOf: backupURL) == sentinel)

        // 3) A fresh, valid store now sits at the original path (different from the corrupt one).
        #expect(fm.fileExists(atPath: storeURL.path))
        #expect((try? Data(contentsOf: storeURL)) != sentinel)

        try? fm.removeItem(at: storeURL)
        try? fm.removeItem(at: backupURL)
    }

    /// The happy path (no pre-existing store) must not fabricate a backup or otherwise
    /// disturb anything — recovery only kicks in on a real open failure.
    @Test func cleanStoreNeedsNoRecovery() throws {
        let fm = FileManager.default
        let storeURL = uniqueStoreURL()

        let container = SafetyWalkModelContainer.makeRecoverable(
            schema: Self.schema,
            migrationPlan: nil,
            storeURL: storeURL,
            backupSuffix: "wo9test"
        ) {
            ModelConfiguration(schema: Self.schema, url: storeURL)
        }

        let ctx = ModelContext(container)
        ctx.insert(Site(name: "클린 현장"))
        try ctx.save()
        #expect(try ctx.fetch(FetchDescriptor<Site>()).count == 1)

        let backupURL = URL(fileURLWithPath: storeURL.path + ".wo9test.bak")
        #expect(fm.fileExists(atPath: backupURL.path) == false)

        try? fm.removeItem(at: storeURL)
    }

    /// Move-aside must carry the SQLite sidecars (`-shm`, `-wal`) too, and preserve every
    /// byte — a half-moved store is as unopenable as the original.
    @Test func moveStoreAsideCarriesSidecarsAndPreservesBytes() throws {
        let fm = FileManager.default
        let storeURL = uniqueStoreURL()
        let shm = URL(fileURLWithPath: storeURL.path + "-shm")
        let wal = URL(fileURLWithPath: storeURL.path + "-wal")
        let files: [(URL, Data)] = [
            (storeURL, Data("store".utf8)),
            (shm, Data("shm".utf8)),
            (wal, Data("wal".utf8)),
        ]
        for (url, data) in files { try data.write(to: url) }

        let moved = SafetyWalkModelContainer.moveStoreAside(storeURL: storeURL, backupSuffix: "wo9test")

        #expect(moved.count == 3)
        for (url, data) in files {
            let backup = URL(fileURLWithPath: url.path + ".wo9test.bak")
            #expect(fm.fileExists(atPath: url.path) == false)      // original gone from its path
            #expect(fm.fileExists(atPath: backup.path))            // present at backup
            #expect(try Data(contentsOf: backup) == data)          // bytes intact
            try? fm.removeItem(at: backup)
        }
    }
}
