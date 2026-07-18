import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2d §4/§5 — 공유 기록의 최신성(stale) 판정과 KR 법정 게이트.
// 사전: 일정이 바뀌면 이전 사전 공유는 현재 일정과 불일치. KR은 현재 사전 공유가 있어야 시작·확정 가능.
// 사후: 조치가 바뀌면 이전 사후 공유는 과거 기록으로 남되 '현재 상태 공유'는 아니다. KR closed는 현재 사후 공유 필요.
// US 관할에는 KR 전용 게이트를 강제하지 않는다. jurisdiction nil = '관할 미설정' — 법규 충족 자동 주장 금지.

@Suite("SharingEventPolicy — 최신성 + KR 관할 게이트 (LEGAL-2d)")
struct SharingGateTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let scheduled = Date(timeIntervalSince1970: 1_700_600_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true) // threshold 2

    private func plannedAssessment(in ctx: ModelContext,
                                   jurisdiction: JurisdictionCode?) throws -> RiskAssessment {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                                jurisdictionSnapshot: jurisdiction,
                                scheduledAt: scheduled)
        ctx.insert(ra)
        try ctx.save()
        return ra
    }

    @discardableResult
    private func recordPre(_ ra: RiskAssessment, in ctx: ModelContext, at date: Date? = nil) throws -> SharingEvent {
        try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                         target: "전 근로자", ownerName: "홍길동",
                                         at: date ?? when, context: ctx)
    }

    /// planned(+선택적 사전공유) → inProgress → 항목 1건(기준 이내, 조치 불필요) 확정.
    private func readyToFinalize(in ctx: ModelContext, jurisdiction: JurisdictionCode?,
                                 withPreSharing: Bool) throws -> RiskAssessment {
        let ra = try plannedAssessment(in: ctx, jurisdiction: jurisdiction)
        if withPreSharing { try recordPre(ra, in: ctx) }
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        ra.items = []
        let item = RiskAssessmentItem(taskDescription: "운반", hazardDescription: "협착",
                                      likelihood: 1, severity: 1, riskLevel: .low)
        item.riskAssessment = ra
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        ctx.insert(item)
        ra.items = [item]
        try ctx.save()
        return ra
    }

    // MARK: - 이력 정렬

    @Test("공유 이력은 시간 역순으로 정렬된다")
    func historyIsReverseChronological() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        try recordPre(ra, in: ctx, at: when)
        try recordPre(ra, in: ctx, at: when.addingTimeInterval(7200))
        try recordPre(ra, in: ctx, at: when.addingTimeInterval(3600))

        let sorted = SharingEventPolicy.sortedEvents(ra)
        #expect(sorted.count == 3)
        let times = sorted.compactMap(\.sharedAt)
        #expect(times == times.sorted(by: >))
    }

    // MARK: - 사전 공유 최신성 (일정 변경)

    @Test("일정이 바뀌면 이전 사전 공유는 현재 일정과 불일치(stale)한 것으로 표시된다")
    func scheduleChangeMakesPreSharingStale() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        let event = try recordPre(ra, in: ctx)
        #expect(!SharingEventPolicy.isStale(event, in: ra))
        #expect(SharingEventPolicy.currentEvent(phase: .pre, in: ra) === event)

        ra.scheduledAt = scheduled.addingTimeInterval(86_400)   // 일정 하루 연기
        try ctx.save()

        #expect(SharingEventPolicy.isStale(event, in: ra))
        #expect(SharingEventPolicy.currentEvent(phase: .pre, in: ra) == nil)
        // 과거 기록 자체는 보존된다 — stale 은 삭제가 아니다.
        #expect((ra.sharingEvents ?? []).count == 1)
    }

    @Test("일정을 지우면 사전 공유는 fail-closed로 stale 처리된다")
    func clearedScheduleFailsClosed() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        let event = try recordPre(ra, in: ctx)
        ra.scheduledAt = nil
        try ctx.save()
        #expect(SharingEventPolicy.isStale(event, in: ra))
    }

    @Test("손상된 스냅샷을 가진 공유 기록은 fail-closed로 stale 처리된다")
    func corruptSnapshotIsStale() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        // 기록된 공유는 외부에서 수정할 수 없다(생성 즉시 불변) — 손상 레코드는 CloudKit 이 배달했거나
        // 저장소가 깨진 상황을 뜻하므로, Core 내부 data init 으로 그 상태를 직접 구성해 검증한다.
        let corrupt = SharingEvent(phase: .pre, method: .posting, sharedAt: when,
                                   target: "전 근로자", contentSnapshot: "{ 손상", ownerName: "홍길동")
        ctx.insert(corrupt)
        corrupt.riskAssessment = ra
        ra.sharingEvents = (ra.sharingEvents ?? []) + [corrupt]
        try ctx.save()

        #expect(SharingEventPolicy.isStale(corrupt, in: ra))
        #expect(SharingEventPolicy.currentEvent(phase: .pre, in: ra) == nil)
        // 손상 기록은 현재 공유로 세지 않으므로 KR 시작 게이트도 닫힌 상태여야 한다.
        #expect(!SharingEventPolicy.satisfiesPreSharingGate(ra))
    }

    @Test("기록된 공유는 생성 이후 값이 바뀌지 않는다 (편집 API 부재)")
    func recordedEventIsImmutable() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        let event = try recordPre(ra, in: ctx)
        let snapshotAtRecord = event.contentSnapshot

        // 평가 원본을 바꿔도 기록된 공유의 값은 그대로다 (값 복사 + setter 봉인).
        ra.scheduledAt = scheduled.addingTimeInterval(86_400)
        ra.siteName = "2공장"
        try ctx.save()

        #expect(event.contentSnapshot == snapshotAtRecord)
        #expect(event.target == "전 근로자")
        #expect(event.sharedAt == when)
        let decoded = try SharingEventPolicy.decodeSnapshot(event)
        #expect(decoded.siteName == "1공장")          // 당시 값
        #expect(decoded.scheduledAt == scheduled)     // 당시 일정
    }

    // MARK: - 사후 공유 최신성 (조치 변경)

    @Test("개선조치가 바뀌면 이전 사후 공유는 과거 기록으로 남되 현재 상태 공유는 아니다")
    func actionChangeMakesPostSharingStale() throws {
        let ctx = try makeContext()
        let ra = try readyToFinalize(in: ctx, jurisdiction: .kr, withPreSharing: true)
        try AssessmentFinalization.finalize(ra, now: when, in: ctx)
        let post = try SharingEventRecording.record(phase: .post, method: .written, in: ra,
                                                    target: "전 근로자", ownerName: "홍길동",
                                                    at: when, context: ctx)
        #expect(!SharingEventPolicy.isStale(post, in: ra))

        // finalized 후에도 개선조치는 별도 수명주기로 수정 가능 (LEGAL_2_ARCH §1).
        let item = try #require(ra.items?.first)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "추가 대책",
                                        at: when.addingTimeInterval(3600), context: ctx)

        #expect(SharingEventPolicy.isStale(post, in: ra))
        #expect(SharingEventPolicy.currentEvent(phase: .post, in: ra) == nil)
        #expect((ra.sharingEvents ?? []).contains { $0 === post })   // 과거 기록 보존
    }

    // MARK: - KR 게이트: 평가 시작

    @Test("KR 관할은 현재 일정과 일치하는 사전 공유 기록이 있어야 평가를 시작할 수 있다")
    func krRequiresCurrentPreSharingToStart() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)

        #expect(throws: AssessmentStartError.missingCurrentPreSharing) {
            try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        }
        #expect(ra.status == .planned)
        #expect(ra.criteria == nil)

        try recordPre(ra, in: ctx)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        #expect(ra.status == .inProgress)
    }

    @Test("사전 공유 후 일정을 바꾸면 KR 평가는 다시 시작할 수 없다")
    func krStaleePreSharingBlocksStart() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        try recordPre(ra, in: ctx)
        ra.scheduledAt = scheduled.addingTimeInterval(86_400)
        try ctx.save()

        #expect(throws: AssessmentStartError.missingCurrentPreSharing) {
            try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        }
    }

    @Test("US 관할에는 KR 사전공유 게이트를 강제하지 않는다")
    func usHasNoPreSharingStartGate() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .us)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        #expect(ra.status == .inProgress)
    }

    @Test("관할 미설정 평가에도 KR 게이트를 강제하지 않지만 법규 충족을 주장하지도 않는다")
    func unsetJurisdictionIsFailClosedNotClaimed() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: nil)
        #expect(SharingEventPolicy.jurisdictionState(ra) == .unset)
        #expect(!SharingEventPolicy.requiresPreSharingGate(ra))
        #expect(!SharingEventPolicy.requiresPostSharingGate(ra))

        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        #expect(ra.status == .inProgress)
    }

    @Test("관할 상태는 kr/us/미설정 세 가지로 구분된다")
    func jurisdictionStates() throws {
        let ctx = try makeContext()
        #expect(SharingEventPolicy.jurisdictionState(try plannedAssessment(in: ctx, jurisdiction: .kr)) == .kr)
        #expect(SharingEventPolicy.jurisdictionState(try plannedAssessment(in: ctx, jurisdiction: .us)) == .us)
        #expect(SharingEventPolicy.jurisdictionState(try plannedAssessment(in: ctx, jurisdiction: nil)) == .unset)
    }

    // MARK: - current 공유 이벤트 완전성 (반송 1차 P1-B)
    // CloudKit 은 모든 속성을 optional 로 저장하므로 부분 채워진 레코드가 배달될 수 있다. 그런 레코드가
    // "현재 유효한 공유"로 인정되면 KR 게이트가 잘못 열린다 — 완전성은 Core 검증 함수 하나가 소유한다.

    /// 정상 경로로 만든 유효 스냅샷 JSON (손상 레코드에 심어 다른 결함만 분리 검증하기 위함).
    private func validPreSnapshotJSON(_ ra: RiskAssessment) throws -> String {
        try SharingEventPolicy.makeSnapshotJSON(phase: .pre, for: ra)
    }

    /// 손상 레코드를 평가에 붙인다 (Core-internal corruption seam).
    @discardableResult
    private func attachCorrupted(to ra: RiskAssessment, in ctx: ModelContext,
                                 phase: SharingPhase? = .pre, method: SharingMethod? = .posting,
                                 sharedAt: Date? = nil, target: String? = "전 근로자",
                                 snapshot: String, ownerName: String? = "홍길동") -> SharingEvent {
        let event = SharingEvent(corruptedPhase: phase, method: method,
                                 sharedAt: sharedAt ?? when, target: target,
                                 contentSnapshot: snapshot, ownerName: ownerName)
        ctx.insert(event)
        event.riskAssessment = ra
        ra.sharingEvents = (ra.sharingEvents ?? []) + [event]
        try? ctx.save()
        return event
    }

    private func expectNotCurrent(_ ra: RiskAssessment, _ label: Comment) {
        #expect(SharingEventPolicy.currentEvent(phase: .pre, in: ra) == nil, label)
        #expect(!SharingEventPolicy.satisfiesPreSharingGate(ra), label)
    }

    @Test("공유 방법이 없는 손상 레코드는 current 가 아니다")
    func nilMethodIsNotCurrent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        attachCorrupted(to: ra, in: ctx, method: nil, snapshot: try validPreSnapshotJSON(ra))
        expectNotCurrent(ra, "nil method")
    }

    @Test("공유 시각이 없는 손상 레코드는 current 가 아니다")
    func nilSharedAtIsNotCurrent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        let json = try validPreSnapshotJSON(ra)
        let event = SharingEvent(corruptedPhase: .pre, method: .posting, sharedAt: nil,
                                 target: "전 근로자", contentSnapshot: json, ownerName: "홍길동")
        ctx.insert(event)
        event.riskAssessment = ra
        ra.sharingEvents = (ra.sharingEvents ?? []) + [event]
        try ctx.save()
        expectNotCurrent(ra, "nil sharedAt")
    }

    @Test("공유 시점이 없는 손상 레코드는 current 가 아니다")
    func nilPhaseIsNotCurrent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        attachCorrupted(to: ra, in: ctx, phase: nil, snapshot: try validPreSnapshotJSON(ra))
        expectNotCurrent(ra, "nil phase")
    }

    @Test("공백 대상을 가진 손상 레코드는 current 가 아니다")
    func blankTargetIsNotCurrent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        attachCorrupted(to: ra, in: ctx, target: "   ", snapshot: try validPreSnapshotJSON(ra))
        expectNotCurrent(ra, "blank target")
    }

    @Test("공백 담당자를 가진 손상 레코드는 current 가 아니다")
    func blankOwnerIsNotCurrent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        attachCorrupted(to: ra, in: ctx, snapshot: try validPreSnapshotJSON(ra), ownerName: "  ")
        expectNotCurrent(ra, "blank owner")
    }

    @Test("빈 스냅샷을 가진 손상 레코드는 current 가 아니다")
    func emptySnapshotIsNotCurrent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        attachCorrupted(to: ra, in: ctx, snapshot: "")
        expectNotCurrent(ra, "empty snapshot")
    }

    @Test("다른 평가의 스냅샷을 심은 레코드는 current 가 아니다")
    func foreignAssessmentIdIsNotCurrent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        let other = try plannedAssessment(in: ctx, jurisdiction: .kr)
        attachCorrupted(to: ra, in: ctx, snapshot: try validPreSnapshotJSON(other))
        expectNotCurrent(ra, "foreign assessmentId")
    }

    @Test("스냅샷의 시점이 이벤트 시점과 다르면 current 가 아니다")
    func phaseMismatchIsNotCurrent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        // 이벤트는 .pre 라고 주장하지만 스냅샷 본문은 "post" 다.
        let tampered = try validPreSnapshotJSON(ra)
            .replacingOccurrences(of: "\"phase\":\"pre\"", with: "\"phase\":\"post\"")
        attachCorrupted(to: ra, in: ctx, snapshot: tampered)
        expectNotCurrent(ra, "phase mismatch between event and snapshot")
    }

    @Test("다른 평가가 소유한 이벤트는 이 평가의 current 가 아니다 — 소유 조건만으로 걸러진다")
    func eventOwnedByAnotherAssessmentIsNotCurrent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        let other = try plannedAssessment(in: ctx, jurisdiction: .kr)

        // ★ 소유 조건을 **격리**한다: 스냅샷은 `ra` 것으로 만들어 assessmentId·phase·값 비교를 전부
        // 통과시키고, 이벤트만 `other` 가 소유하게 붙인다. 그러면 이 이벤트를 걸러내는 것은 오직
        // "이 평가가 소유한 이벤트인가" 조건뿐이다 — 그 가드를 지우면 이 테스트가 빨개진다.
        let snapshotOfRA = try SharingEventPolicy.makeSnapshotJSON(phase: .pre, for: ra)
        let foreign = SharingEvent(corruptedPhase: .pre, method: .posting, sharedAt: when,
                                   target: "전 근로자", contentSnapshot: snapshotOfRA,
                                   ownerName: "홍길동")
        ctx.insert(foreign)
        foreign.riskAssessment = other
        other.sharingEvents = (other.sharingEvents ?? []) + [foreign]
        try ctx.save()

        // 다른 조건은 모두 통과하는 이벤트임을 먼저 확인한다(가드 격리 증명).
        let recorded = try SharingEventPolicy.decodeSnapshot(foreign)
        #expect(recorded.assessmentId == ra.id)
        #expect(recorded.phase == SharingPhase.pre.rawValue)
        #expect(recorded == (try SharingEventPolicy.makeSnapshot(phase: .pre, for: ra)))
        #expect(SharingEventPolicy.isComplete(foreign))

        // 그럼에도 ra 의 current 는 아니다 — 소유가 다르기 때문.
        #expect(!SharingEventPolicy.isCurrent(foreign, phase: .pre, in: ra))
        expectNotCurrent(ra, "event belongs to another assessment")
    }

    @Test("정상 기록은 완전성 검증을 모두 통과한다 — vacuous pass 차단")
    func validRecordIsCurrent() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        let event = try recordPre(ra, in: ctx)
        #expect(SharingEventPolicy.isCurrent(event, phase: .pre, in: ra))
        #expect(SharingEventPolicy.currentEvent(phase: .pre, in: ra) === event)
        #expect(SharingEventPolicy.satisfiesPreSharingGate(ra))
    }

    @Test("불완전한 이벤트는 validate 에서도 같은 계약으로 거부된다")
    func validateRejectsIncompleteRecords() throws {
        let json = "{}"
        #expect(throws: ModelValidationError.emptyTarget) {
            try SharingEvent(corruptedPhase: .pre, method: .posting, sharedAt: when,
                             target: "  ", contentSnapshot: json, ownerName: "홍길동").validate()
        }
        #expect(throws: ModelValidationError.emptyOwnerName) {
            try SharingEvent(corruptedPhase: .pre, method: .posting, sharedAt: when,
                             target: "전 근로자", contentSnapshot: json, ownerName: nil).validate()
        }
        #expect(throws: ModelValidationError.emptyContentSnapshot) {
            try SharingEvent(corruptedPhase: .pre, method: .posting, sharedAt: when,
                             target: "전 근로자", contentSnapshot: "  ", ownerName: "홍길동").validate()
        }
        #expect(throws: ModelValidationError.missingMethod) {
            try SharingEvent(corruptedPhase: .pre, method: nil, sharedAt: when,
                             target: "전 근로자", contentSnapshot: json, ownerName: "홍길동").validate()
        }
    }

    // MARK: - 생성자 봉인 (WO LEGAL-2d §5)

    @Test("새로 만든 평가는 항상 planned 이며 확정 상태로 태어날 수 없다")
    func newAssessmentIsAlwaysPlanned() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .kr)
        // 생성자에 status 인자가 없으므로 임의의 .finalized 레코드를 만들 방법이 없다.
        #expect(ra.status == .planned)
        #expect(ra.finalizedAt == nil)

        // status·finalizedAt 은 internal(set) — 패키지 밖(앱·macOS)에서는 쓸 수 없고, 확정은 오직
        // AssessmentFinalization.finalize 를 통해서만 일어난다.
        try AssessmentFinalization.finalize(
            try readyToFinalize(in: ctx, jurisdiction: .us, withPreSharing: false),
            now: when, in: ctx)
    }

    // MARK: - 확정(finalize) 원자 연산

    @Test("확정은 inProgress 평가만 허용한다")
    func finalizeOnlyFromInProgress() throws {
        let ctx = try makeContext()
        let planned = try plannedAssessment(in: ctx, jurisdiction: .us)
        #expect(throws: AssessmentFinalizeError.notInProgress) {
            try AssessmentFinalization.finalize(planned, now: when, in: ctx)
        }

        let ra = try readyToFinalize(in: ctx, jurisdiction: .us, withPreSharing: false)
        try AssessmentFinalization.finalize(ra, now: when, in: ctx)
        #expect(ra.status == .finalized)
        #expect(ra.finalizedAt == when)
        #expect(ra.updatedAt == when)

        // 재확정 금지
        #expect(throws: AssessmentFinalizeError.notInProgress) {
            try AssessmentFinalization.finalize(ra, now: when, in: ctx)
        }
    }

    @Test("확정은 readiness 전건을 다시 검증한다 — 미충족이면 상태가 변하지 않는다")
    func finalizeReVerifiesReadiness() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx, jurisdiction: .us)
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        ra.items = []
        // 기준 초과인데 개선조치 계획이 없는 항목 → readiness 미충족
        let item = RiskAssessmentItem(taskDescription: "고소", hazardDescription: "추락",
                                      likelihood: 3, severity: 3, riskLevel: .high)
        item.riskAssessment = ra
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        ctx.insert(item)
        ra.items = [item]
        try ctx.save()

        #expect(!AssessmentFinalization.isReadyToFinalize(ra))
        #expect(throws: AssessmentFinalizeError.notReady) {
            try AssessmentFinalization.finalize(ra, now: when, in: ctx)
        }
        #expect(ra.status == .inProgress)
        #expect(ra.finalizedAt == nil)
    }

    @Test("KR 확정은 현재 사전 공유 기록을 다시 검증한다")
    func krFinalizeReVerifiesPreSharing() throws {
        let ctx = try makeContext()
        let ra = try readyToFinalize(in: ctx, jurisdiction: .kr, withPreSharing: true)
        // 시작 후 일정을 바꾸면 사전 공유가 stale 이 되어 확정도 막힌다.
        ra.scheduledAt = scheduled.addingTimeInterval(86_400)
        try ctx.save()

        #expect(throws: AssessmentFinalizeError.missingCurrentPreSharing) {
            try AssessmentFinalization.finalize(ra, now: when, in: ctx)
        }
        #expect(ra.status == .inProgress)
        #expect(ra.finalizedAt == nil)
    }

    @Test("save 실패 시 확정은 상태·시각을 store와 메모리 양쪽에서 원복한다")
    func failedFinalizeRestoresStatusAndTimestamps() throws {
        let ctx = try makeContext()
        let ra = try readyToFinalize(in: ctx, jurisdiction: .us, withPreSharing: false)
        let priorUpdatedAt = ra.updatedAt

        struct Boom: Error {}
        #expect(throws: Boom.self) {
            try AssessmentFinalization.finalize(ra, now: when.addingTimeInterval(999),
                                                in: ctx, commit: { throw Boom() })
        }

        #expect(ra.status == .inProgress)
        #expect(ra.finalizedAt == nil)
        #expect(ra.updatedAt == priorUpdatedAt)

        let stored = try ctx.fetch(FetchDescriptor<RiskAssessment>())
        #expect(stored.first?.status == .inProgress)
        #expect(stored.first?.finalizedAt == nil)
    }

    // MARK: - KR 게이트: closed 파생

    @Test("KR 평가의 closed 파생에는 현재 상태와 일치하는 사후 공유 기록이 필요하다")
    func krClosedRequiresCurrentPostSharing() throws {
        let ctx = try makeContext()
        let ra = try readyToFinalize(in: ctx, jurisdiction: .kr, withPreSharing: true)
        try AssessmentFinalization.finalize(ra, now: when, in: ctx)

        // 기준 초과 항목이 없어 필수 조치는 없지만, KR은 사후 공유가 없으면 아직 종결이 아니다.
        #expect(!AssessmentClosure.isClosed(ra))

        let post = try SharingEventRecording.record(phase: .post, method: .written, in: ra,
                                                    target: "전 근로자", ownerName: "홍길동",
                                                    at: when, context: ctx)
        #expect(AssessmentClosure.isClosed(ra))

        // 조치가 바뀌면 그 사후 공유는 현재 상태 공유가 아니므로 다시 미종결.
        let item = try #require(ra.items?.first)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "사후 추가 대책",
                                        at: when.addingTimeInterval(60), context: ctx)
        #expect(SharingEventPolicy.isStale(post, in: ra))
        #expect(!AssessmentClosure.isClosed(ra))
    }

    @Test("US 평가의 기존 closed 규칙에는 KR 전용 사후공유 조건을 강제하지 않는다")
    func usClosedIgnoresPostSharingGate() throws {
        let ctx = try makeContext()
        let ra = try readyToFinalize(in: ctx, jurisdiction: .us, withPreSharing: false)
        try AssessmentFinalization.finalize(ra, now: when, in: ctx)
        // 사후 공유 기록이 없어도 기준 초과 0건이면 종결로 파생된다 (LEGAL_2_ARCH §1.1).
        #expect(AssessmentClosure.isClosed(ra))
    }

    @Test("관할 미설정 평가의 closed 파생에도 KR 전용 조건을 강제하지 않는다")
    func unsetJurisdictionClosedIgnoresPostSharingGate() throws {
        let ctx = try makeContext()
        let ra = try readyToFinalize(in: ctx, jurisdiction: nil, withPreSharing: false)
        try AssessmentFinalization.finalize(ra, now: when, in: ctx)
        #expect(AssessmentClosure.isClosed(ra))
    }
}
