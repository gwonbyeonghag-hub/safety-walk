import Testing
import Foundation
import SwiftData
import SafetyWalkCore
import UIKit
@testable import 현장_안전_지킴이

/// WO LEGAL-2c (반송 3차) — the editor ViewModel's INJECTED photo encoder: a newly picked photo is
/// compressed exactly once; an unchanged existing photo is never re-compressed; an encoder failure
/// surfaces as the distinct 압축 실패 alert (not the save alert). swift-testing @MainActor (the VM is
/// @Observable @MainActor + does SwiftData saves — see the app-viewmodel-tests-swift-testing note).
@MainActor
@Suite("CorrectiveActionEditorViewModel — photo encoder injection (LEGAL-2c 3차)")
struct CorrectiveActionEditorViewModelTests {

    private let when = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// A saved inProgress assessment with one COMPLETED corrective action (이행일·개선후위험도 set).
    private func completedFixture(in ctx: ModelContext)
        throws -> (RiskAssessment, RiskAssessmentItem, CorrectiveAction) {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "현장", assessorName: "평가자")
        ctx.insert(ra)
        let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        let item = RiskAssessmentItem(likelihood: 2, severity: 2, riskLevel: .medium)
        item.riskAssessment = ra
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        ctx.insert(item); ra.items = [item]
        try ctx.save()
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "난간 설치", at: when, context: ctx)
        try CorrectiveActionEditing.update(action, in: ra, measure: "난간 설치", status: .completed,
                                           implementedAt: when, postRiskLevel: .low, at: when, context: ctx)
        return (ra, item, action)
    }

    @Test func newPhotoCompressedExactlyOnce() throws {
        let ctx = try makeContext()
        let (ra, item, action) = try completedFixture(in: ctx)
        var calls = 0
        let vm = CorrectiveActionEditorViewModel(assessment: ra, item: item, action: action,
                                                 encode: { _ in calls += 1; return Data([1, 2, 3]) })
        vm.setPickedImage(UIImage())
        #expect(vm.save(context: ctx))
        #expect(calls == 1)
        #expect(action.evidencePhotoData == Data([1, 2, 3]))
    }

    @Test func unchangedPhotoNotRecompressed() throws {
        let ctx = try makeContext()
        let (ra, item, action) = try completedFixture(in: ctx)
        var calls = 0
        let vm1 = CorrectiveActionEditorViewModel(assessment: ra, item: item, action: action,
                                                  encode: { _ in calls += 1; return Data([9]) })
        vm1.setPickedImage(UIImage())
        _ = vm1.save(context: ctx)
        #expect(calls == 1)
        // Reopen and save WITHOUT touching the photo → the encoder is not called again.
        let vm2 = CorrectiveActionEditorViewModel(assessment: ra, item: item, action: action,
                                                  encode: { _ in calls += 1; return Data([0]) })
        #expect(vm2.save(context: ctx))
        #expect(calls == 1)                                // no additional call
        #expect(action.evidencePhotoData == Data([9]))     // photo unchanged
    }

    @Test func encoderFailureSurfacesAsCompressError() throws {
        struct EncodeFailed: Error {}
        let ctx = try makeContext()
        let (ra, item, action) = try completedFixture(in: ctx)
        let vm = CorrectiveActionEditorViewModel(assessment: ra, item: item, action: action,
                                                 encode: { _ in throw EncodeFailed() })
        vm.setPickedImage(UIImage())
        #expect(vm.save(context: ctx) == false)
        #expect(vm.showCompressError)       // distinct 압축 실패 alert
        #expect(!vm.showSaveError)          // not the save alert
    }
}
