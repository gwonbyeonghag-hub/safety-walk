import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO-3: proves the V1→V2 migration is lossless for real, already-on-disk data — an
// on-disk store is seeded using the pre-retrofit (SchemaV1) shapes, exactly how the
// currently-shipping app's data looks today, then reopened through
// `SafetyWalkMigrationPlan` and the legacy file-based photos must have moved into
// `photoData` with the legacy files gone.

@Suite("SafetyWalkMigrationPlan — V1→V2 photo migration (WO-3)")
struct SchemaMigrationTests {

    private func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-test-\(UUID().uuidString)")
            .appendingPathExtension("store")
    }

    private func tempLegacyRoot() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-legacy-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func existingFilePhotosMigrateIntoPhotoDataAndLegacyFilesAreDeleted() throws {
        let storeURL = tempStoreURL()
        let legacyRoot = tempLegacyRoot()
        SafetyWalkMigrationPlan.legacyRoot = legacyRoot

        // 1. Write two legacy photo files, exactly as the pre-WO-3 PhotoStorageService did.
        let photoFolder = legacyRoot.appendingPathComponent("EvidencePhotos", isDirectory: true)
        try FileManager.default.createDirectory(at: photoFolder, withIntermediateDirectories: true)
        let itemPhotoBytes = Data("item-photo-bytes".utf8)
        let hazardPhotoBytes = Data("hazard-photo-bytes".utf8)
        let itemRelativePath = "EvidencePhotos/item.jpg"
        let hazardRelativePath = "EvidencePhotos/hazard.jpg"
        try itemPhotoBytes.write(to: photoFolder.appendingPathComponent("item.jpg"))
        try hazardPhotoBytes.write(to: photoFolder.appendingPathComponent("hazard.jpg"))

        // 2. Seed an on-disk store using the pre-retrofit (SchemaV1) shapes — this is
        //    exactly what the currently-installed app's real on-disk data looks like.
        let itemId: UUID
        let hazardId: UUID
        do {
            let schema = Schema(SchemaV1.models)
            let config = ModelConfiguration(schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: config)
            let context = ModelContext(container)

            let inspection = SchemaV1.Inspection(siteId: UUID(), siteName: "현장",
                                                  inspectorName: "김점검", templateId: "t")
            context.insert(inspection)
            let item = SchemaV1.ChecklistItem(inspectionId: inspection.id, templateItemId: "t1",
                                               title: "항목", category: "cat", sortOrder: 0)
            item.photoPath = itemRelativePath
            context.insert(item)
            inspection.items.append(item)

            let hazard = SchemaV1.Hazard(siteId: inspection.siteId, location: "위치", type: .general,
                                         riskLevel: .low, hazardDescription: "설명",
                                         photoPath: hazardRelativePath, inspectionId: inspection.id)
            context.insert(hazard)
            inspection.hazards.append(hazard)

            try context.save()
            itemId = item.id
            hazardId = hazard.id
        }

        // 3. Reopen at SchemaV2 through the real migration plan — this is what
        //    SafetyWalkApp.swift / MacModelContainer.swift do in production.
        let v2Schema = Schema(versionedSchema: SchemaV2.self)
        let v2Config = ModelConfiguration(schema: v2Schema, url: storeURL)
        let migratedContainer = try ModelContainer(
            for: v2Schema,
            migrationPlan: SafetyWalkMigrationPlan.self,
            configurations: v2Config
        )
        let migratedContext = ModelContext(migratedContainer)

        let migratedItem = try #require(
            try migratedContext.fetch(FetchDescriptor<ChecklistItem>()).first { $0.id == itemId })
        let migratedHazard = try #require(
            try migratedContext.fetch(FetchDescriptor<Hazard>()).first { $0.id == hazardId })

        #expect(migratedItem.photoData == itemPhotoBytes)
        #expect(migratedHazard.photoData == hazardPhotoBytes)

        // 4. Legacy files are cleaned up once their bytes are safely inside photoData.
        #expect(!FileManager.default.fileExists(atPath: photoFolder.appendingPathComponent("item.jpg").path))
        #expect(!FileManager.default.fileExists(atPath: photoFolder.appendingPathComponent("hazard.jpg").path))
    }
}
