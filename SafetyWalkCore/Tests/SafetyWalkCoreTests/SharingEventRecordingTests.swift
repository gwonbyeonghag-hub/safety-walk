import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2d — 공유 기록 생성 관문. 2c의 CorrectiveAction 패턴과 동일하게 data-only init 은 Core
// 내부로 제한하고, 외부 생성은 원자적 Core 연산 하나(`SharingEventRecording.record`)만 허용한다.
// 생성 즉시 불변: 편집·삭제 op 자체가 존재하지 않는다. 실제 공유가 여러 번 있을 수 있으므로 dedup 금지.

@Suite("SharingEventRecording — 생성 관문 + 원자 기록 (LEGAL-2d)")
struct SharingEventRecordingTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let scheduled = Date(timeIntervalSince1970: 1_700_600_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true)

    private func plannedAssessment(in ctx: ModelContext,
                                   jurisdiction: JurisdictionCode? = .kr,
                                   schedule: Date? = nil) throws -> RiskAssessment {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                                jurisdictionSnapshot: jurisdiction,
                                status: .planned, scheduledAt: schedule ?? scheduled)
        ctx.insert(ra)
        try ctx.save()
        return ra
    }

    /// planned → inProgress → (항목 1건 확정 + 조치 계획) → finalized.
    private func finalizedAssessment(in ctx: ModelContext,
                                     jurisdiction: JurisdictionCode? = .kr) throws -> RiskAssessment {
        let ra = try plannedAssessment(in: ctx, jurisdiction: jurisdiction)
        if jurisdiction == .kr {
            try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                             target: "전 근로자", ownerName: "홍길동",
                                             at: when, context: ctx)
        }
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        ra.items = []
        let item = RiskAssessmentItem(taskDescription: "고소작업", hazardDescription: "추락",
                                      likelihood: 1, severity: 1, riskLevel: .low)
        item.riskAssessment = ra
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        ctx.insert(item)
        ra.items = [item]
        try ctx.save()
        try AssessmentFinalization.finalize(ra, now: when, in: ctx)
        return ra
    }

    // MARK: - 생성 우회 차단

    @Test("TBM은 SharingEvent 방식으로 표현될 수 없다 — SharingMethod는 비TBM 4종뿐")
    func tbmIsNotARepresentableSharingMethod() {
        #expect(SharingMethod.allCases.map(\.rawValue).sorted()
                == ["education", "electronic", "posting", "written"])
        // TBM 공유 증명은 SafetyBriefing 자체다 (LEGAL_2_ARCH §3 이중 저장 제거).
        #expect(!SharingMethod.allCases.contains { $0.rawValue.lowercased().contains("tbm") })
        #expect(!SharingMethod.allCases.contains { $0.rawValue.lowercased().contains("briefing") })
    }

    @Test("공백 대상은 저장되지 않는다")
    func blankTargetIsRefused() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        for blank in ["", "   ", "\n\t"] {
            #expect(throws: SharingRecordError.emptyTarget) {
                try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                                 target: blank, ownerName: "홍길동",
                                                 at: when, context: ctx)
            }
        }
        #expect((ra.sharingEvents ?? []).isEmpty)
    }

    @Test("공백 담당자는 저장되지 않는다")
    func blankOwnerIsRefused() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        #expect(throws: SharingRecordError.emptyOwner) {
            try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                             target: "전 근로자", ownerName: "  ",
                                             at: when, context: ctx)
        }
        #expect((ra.sharingEvents ?? []).isEmpty)
    }

    @Test("기록된 공유는 비어 있지 않은 버전형 스냅샷을 항상 갖는다")
    func recordAlwaysCarriesNonEmptySnapshot() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        let event = try SharingEventRecording.record(phase: .pre, method: .education, in: ra,
                                                     target: "협력사 포함 전원", ownerName: "홍길동",
                                                     at: when, context: ctx)
        #expect(!event.contentSnapshot.isEmpty)
        let snap = try SharingSnapshot.decode(event.contentSnapshot)
        #expect(snap.phase == SharingPhase.pre.rawValue)
        #expect(snap.assessmentId == ra.id)
        #expect(event.phase == .pre)
        #expect(event.method == .education)
        #expect(event.sharedAt == when)
        #expect(event.target == "협력사 포함 전원")
        #expect(event.ownerName == "홍길동")
        #expect(event.riskAssessment === ra)
        #expect((ra.sharingEvents ?? []).count == 1)
    }

    // MARK: - 시점(phase) 게이트

    @Test("사전 공유는 planned 평가에서만 기록된다")
    func preSharingOnlyWhilePlanned() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                         target: "전 근로자", ownerName: "홍길동",
                                         at: when, context: ctx)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)

        #expect(throws: SharingRecordError.phaseNotAllowed) {
            try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                             target: "전 근로자", ownerName: "홍길동",
                                             at: when, context: ctx)
        }
    }

    @Test("일정 없는 planned 평가는 사전 공유를 기록할 수 없다")
    func preSharingRequiresSchedule() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        ra.scheduledAt = nil
        try ctx.save()

        #expect(throws: SharingRecordError.missingSchedule) {
            try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                             target: "전 근로자", ownerName: "홍길동",
                                             at: when, context: ctx)
        }
        #expect((ra.sharingEvents ?? []).isEmpty)
    }

    @Test("사후 공유는 finalized 평가에서만 기록된다 — planned/inProgress는 차단")
    func postSharingOnlyWhenFinalized() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)

        #expect(throws: SharingRecordError.phaseNotAllowed) {
            try SharingEventRecording.record(phase: .post, method: .written, in: ra,
                                             target: "전 근로자", ownerName: "홍길동",
                                             at: when, context: ctx)
        }
        try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                         target: "전 근로자", ownerName: "홍길동",
                                         at: when, context: ctx)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        #expect(throws: SharingRecordError.phaseNotAllowed) {
            try SharingEventRecording.record(phase: .post, method: .written, in: ra,
                                             target: "전 근로자", ownerName: "홍길동",
                                             at: when, context: ctx)
        }
    }

    @Test("finalized 평가의 사후 공유는 당시 위험요인·결정·조치를 담아 기록된다")
    func postSharingRecordsFinalizedContent() throws {
        let ctx = try makeContext()
        let ra = try finalizedAssessment(in: ctx)

        let event = try SharingEventRecording.record(phase: .post, method: .electronic, in: ra,
                                                     target: "전 근로자", ownerName: "홍길동",
                                                     at: when, context: ctx)
        let snap = try SharingSnapshot.decode(event.contentSnapshot)
        #expect(snap.phase == SharingPhase.post.rawValue)
        #expect(snap.items.count == 1)
        #expect(snap.items.first?.taskDescription == "고소작업")
        #expect(snap.items.first?.criteriaDecision == CriteriaDecision.withinThreshold.rawValue)
    }

    // MARK: - 중복 허용 (실제 공유가 여러 번 있을 수 있다)

    @Test("같은 방법·대상으로 여러 번 공유해도 각각 별개 기록으로 남는다 (dedup 금지)")
    func multipleIdenticalSharesAreAllKept() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        for i in 0..<3 {
            try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                             target: "전 근로자", ownerName: "홍길동",
                                             at: when.addingTimeInterval(Double(i) * 60),
                                             context: ctx)
        }
        #expect((ra.sharingEvents ?? []).count == 3)
        #expect(Set((ra.sharingEvents ?? []).map(\.id)).count == 3)
    }

    // MARK: - 저장 실패 시 store + memory 원복

    @Test("save 실패 시 공유 기록은 store와 메모리 양쪽에서 사라진다")
    func failedCommitLeavesNoPhantomEvent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                         target: "1차 공유", ownerName: "홍길동",
                                         at: when, context: ctx)
        let priorUpdatedAt = ra.updatedAt

        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try SharingEventRecording.record(phase: .pre, method: .written, in: ra,
                                             target: "2차 공유", ownerName: "홍길동",
                                             at: when.addingTimeInterval(600),
                                             context: ctx, commit: { throw Boom() })
        }

        // 메모리: 유령 기록 없음
        #expect((ra.sharingEvents ?? []).count == 1)
        #expect(!(ra.sharingEvents ?? []).contains { $0.target == "2차 공유" })
        #expect(ra.updatedAt == priorUpdatedAt)

        // store: 다시 조회해도 1건
        let stored = try ctx.fetch(FetchDescriptor<SharingEvent>())
        #expect(stored.count == 1)
        #expect(stored.first?.target == "1차 공유")
    }
}
