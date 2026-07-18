import Testing
import Foundation
import SwiftData
import SafetyWalkCore
@testable import 현장_안전_지킴이

/// WO LEGAL-2d — 공유 기록 ViewModel: 시점은 진입점 고정, 저장은 원자적 Core op 하나로, 실패하면 화면을
/// 닫지 않는다(onSaved 미호출). swift-testing @MainActor (VM 은 @Observable @MainActor + SwiftData save
/// — app-viewmodel-tests-swift-testing 메모 참조).
@MainActor
@Suite("SharingRecordViewModel — 생성 성공·실패 + 진입점 고정 (LEGAL-2d)")
struct SharingRecordViewModelTests {

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let scheduled = Date(timeIntervalSince1970: 1_700_600_000)

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return ModelContext(try ModelContainer(for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func plannedAssessment(in ctx: ModelContext,
                                   jurisdiction: JurisdictionCode? = .kr,
                                   schedule: Date? = nil) throws -> RiskAssessment {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "1공장", assessorName: "평가자",
                                jurisdictionSnapshot: jurisdiction,
                                scheduledAt: schedule ?? scheduled)
        ctx.insert(ra)
        try ctx.save()
        return ra
    }

    // MARK: - 진입점 고정

    @Test("시점은 진입점이 정하며 ViewModel 이 바꿀 수 있는 값이 아니다")
    func phaseIsFixedByEntryPoint() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        #expect(SharingRecordViewModel(assessment: ra, phase: .pre).phase == .pre)
        #expect(SharingRecordViewModel(assessment: ra, phase: .post).phase == .post)
    }

    @Test("공유 담당자는 평가자 이름으로 prefill 되고 수정 가능하다")
    func ownerPrefilledFromAssessorAndEditable() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        let vm = SharingRecordViewModel(assessment: ra, phase: .pre)
        #expect(vm.ownerName == "평가자")

        vm.target = "전 근로자"
        vm.ownerName = "실제 공유자"
        var dismissed = false
        vm.save(context: ctx, now: when) { dismissed = true }

        #expect(dismissed)
        #expect(ra.sharingEvents?.first?.ownerName == "실제 공유자")
    }

    // MARK: - 저장 성공

    @Test("유효한 입력은 저장되고 화면을 닫는다")
    func validInputSavesAndDismisses() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        let vm = SharingRecordViewModel(assessment: ra, phase: .pre)
        vm.target = "전 근로자"
        vm.method = .posting

        var dismissed = false
        vm.save(context: ctx, now: when) { dismissed = true }

        #expect(dismissed)
        #expect(!vm.showSaveError)
        #expect((ra.sharingEvents ?? []).count == 1)
        let event = try #require(ra.sharingEvents?.first)
        #expect(event.phase == .pre)
        #expect(event.method == .posting)
        #expect(event.target == "전 근로자")
        #expect(!event.contentSnapshot.isEmpty)
    }

    // MARK: - 저장 가능 조건

    @Test("대상 또는 담당자가 비어 있으면 저장 버튼이 활성화되지 않는다")
    func canSaveRequiresTargetAndOwner() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        let vm = SharingRecordViewModel(assessment: ra, phase: .pre)

        #expect(!vm.canSave)                      // 대상 비어 있음
        vm.target = "   "
        #expect(!vm.canSave)                      // 공백만
        vm.target = "전 근로자"
        #expect(vm.canSave)
        vm.ownerName = "  "
        #expect(!vm.canSave)
    }

    // MARK: - 저장 실패 → 화면 유지

    @Test("사후 공유를 planned 평가에서 시도하면 실패하고 화면을 닫지 않는다")
    func postSharingOnPlannedFailsWithoutDismiss() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        let vm = SharingRecordViewModel(assessment: ra, phase: .post)
        vm.target = "전 근로자"

        var dismissed = false
        vm.save(context: ctx, now: when) { dismissed = true }

        #expect(!dismissed)                       // ★ 실패 시 dismiss 금지
        #expect(vm.showSaveError)
        #expect((ra.sharingEvents ?? []).isEmpty)
    }

    @Test("일정 없는 평가의 사전 공유는 실패하고 그 이유를 구분해 알린다")
    func missingScheduleSurfacesDistinctMessage() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        ra.scheduledAt = nil
        try ctx.save()

        let vm = SharingRecordViewModel(assessment: ra, phase: .pre)
        vm.target = "전 근로자"
        var dismissed = false
        vm.save(context: ctx, now: when) { dismissed = true }

        #expect(!dismissed)
        #expect(vm.showSaveError)
        #expect(vm.saveErrorMessage == LocalizationKey.raSharingScheduleMissing.localized)
    }

    @Test("공백 대상은 Core 관문에서 막히고 그 이유가 표시된다")
    func blankTargetSurfacesDistinctMessage() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        let vm = SharingRecordViewModel(assessment: ra, phase: .pre)
        vm.target = "   "

        var dismissed = false
        vm.save(context: ctx, now: when) { dismissed = true }

        #expect(!dismissed)
        #expect(vm.saveErrorMessage == LocalizationKey.raSharingTargetRequired.localized)
        #expect((ra.sharingEvents ?? []).isEmpty)
    }

    // MARK: - 이력 정렬 (화면이 읽는 순서)

    @Test("공유 이력은 최근 기록이 먼저 온다")
    func historyOrderIsNewestFirst() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        for (i, label) in ["첫번째", "두번째", "세번째"].enumerated() {
            let vm = SharingRecordViewModel(assessment: ra, phase: .pre)
            vm.target = label
            vm.save(context: ctx, now: when.addingTimeInterval(Double(i) * 3600)) { }
        }

        let ordered = SharingEventPolicy.sortedEvents(ra).map(\.target)
        #expect(ordered == ["세번째", "두번째", "첫번째"])
    }

    // MARK: - 스냅샷 상세 decode 오류

    @Test("손상된 스냅샷은 decode 오류로 드러나며 현재 데이터로 대체되지 않는다")
    func corruptSnapshotSurfacesDecodeError() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        let vm = SharingRecordViewModel(assessment: ra, phase: .pre)
        vm.target = "전 근로자"
        vm.save(context: ctx, now: when) { }
        let event = try #require(ra.sharingEvents?.first)

        // 정상 기록은 읽힌다.
        #expect(throws: Never.self) { try SharingEventPolicy.decodeSnapshot(event) }

        // 손상 페이로드는 절대 현재 평가로 대체되지 않고 오류가 된다 (화면은 fail-closed 상태 표시).
        #expect(throws: SharingSnapshotError.malformed) {
            try SharingSnapshot.decode("{ 손상된 기록")
        }
    }
}
