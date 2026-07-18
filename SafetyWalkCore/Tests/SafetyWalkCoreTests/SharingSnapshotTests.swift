import Testing
import Foundation
import SwiftData
@testable import SafetyWalkCore

// WO LEGAL-2d — 공유 내용 스냅샷은 자유 입력 문자열이 아니라 Core가 만든 **버전형 JSON**이다.
// 값 복사(원본이 나중에 바뀌어도 불변) · enum은 raw code · 날짜 인코딩 고정 · item/action 정렬 결정적 ·
// JSON key 정렬 · 사진 binary·참여자 개인정보 미포함 · decode 실패는 fail-closed.

@Suite("SharingSnapshot — 버전형 값 스냅샷 (LEGAL-2d)")
struct SharingSnapshotTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    private let when = Date(timeIntervalSince1970: 1_700_000_000)
    private let scheduled = Date(timeIntervalSince1970: 1_700_600_000)
    private let criteria = AcceptabilityCriteria.makeDefault(usesFrequencySeverity: true) // threshold 2

    private func plannedAssessment(in ctx: ModelContext,
                                   jurisdiction: JurisdictionCode? = .kr) throws -> RiskAssessment {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "1공장",
                                assessorName: "홍길동",
                                jurisdictionSnapshot: jurisdiction,
                                industryProfileSnapshot: .construction,
                                scheduledAt: scheduled)
        ctx.insert(ra)
        try ctx.save()
        return ra
    }

    /// planned → inProgress with a locked criteria. KR 평가는 시행규칙 제37조의3 사전(일정) 공유가
    /// 시작의 전제이므로 먼저 기록한다 (WO LEGAL-2d §4 — 게이트는 Core 가 강제한다).
    private func startedWithItems(in ctx: ModelContext,
                                  jurisdiction: JurisdictionCode? = .kr) throws -> RiskAssessment {
        let ra = try plannedAssessment(in: ctx, jurisdiction: jurisdiction)
        if SharingEventPolicy.requiresPreSharingGate(ra) {
            try SharingEventRecording.record(phase: .pre, method: .posting, in: ra,
                                             target: "전 근로자", ownerName: "홍길동",
                                             at: when, context: ctx)
        }
        try AssessmentStart.start(ra, criteria: criteria, now: when, in: ctx)
        ra.items = []
        try ctx.save()
        return ra
    }

    @discardableResult
    private func addItem(_ ra: RiskAssessment, likelihood: Int, severity: Int, level: RiskLevel,
                         task: String, hazard: String, sortOrder: Int,
                         in ctx: ModelContext) throws -> RiskAssessmentItem {
        let item = RiskAssessmentItem(taskDescription: task, hazardDescription: hazard,
                                      currentControls: "기존 안전난간",
                                      likelihood: likelihood, severity: severity,
                                      riskLevel: level, sortOrder: sortOrder)
        item.riskAssessment = ra
        try item.confirmCriteriaDecision(under: criteria, at: when, by: "홍길동")
        ctx.insert(item)
        ra.items = (ra.items ?? []) + [item]
        try ctx.save()
        return item
    }

    // MARK: - 사전(pre) 스냅샷

    @Test("사전 스냅샷은 일정·평가 문맥을 값 복사하고 항목은 담지 않는다")
    func preSnapshotCarriesScheduleContext() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)

        let snap = try SharingEventPolicy.makeSnapshot(phase: .pre, for: ra)

        #expect(snap.formatVersion == SharingSnapshot.currentFormatVersion)
        #expect(snap.phase == SharingPhase.pre.rawValue)
        #expect(snap.assessmentId == ra.id)
        #expect(snap.siteName == "1공장")
        #expect(snap.kind == RiskAssessmentKind.regular.rawValue)
        #expect(snap.method == RiskAssessmentMethod.frequencySeverity.rawValue)
        #expect(snap.jurisdiction == JurisdictionCode.kr.rawValue)
        #expect(snap.industryProfile == IndustryProfileCode.construction.rawValue)
        #expect(snap.scheduledAt == scheduled)
        #expect(snap.items.isEmpty)   // 사전 공유는 일정 공유 — 항목 결과는 아직 없음
    }

    @Test("일정 없는 planned 평가는 사전 스냅샷을 만들 수 없다")
    func preSnapshotRequiresSchedule() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        ra.scheduledAt = nil
        try ctx.save()

        #expect(throws: SharingRecordError.missingSchedule) {
            try SharingEventPolicy.makeSnapshot(phase: .pre, for: ra)
        }
    }

    // MARK: - 사후(post) 스냅샷 — 값 복사

    @Test("사후 스냅샷은 항목의 작업·위험요인·현재조치·위험도·확정 결정을 값 복사한다")
    func postSnapshotCopiesItemValues() throws {
        let ctx = try makeContext()
        let ra = try startedWithItems(in: ctx)
        try addItem(ra, likelihood: 2, severity: 2, level: .medium,
                    task: "고소작업", hazard: "추락", sortOrder: 0, in: ctx)

        let snap = try SharingEventPolicy.makeSnapshot(phase: .post, for: ra)

        #expect(snap.items.count == 1)
        let item = try #require(snap.items.first)
        #expect(item.taskDescription == "고소작업")
        #expect(item.hazardDescription == "추락")
        #expect(item.currentControls == "기존 안전난간")
        #expect(item.riskLevel == RiskLevel.medium.rawValue)
        #expect(item.likelihood == 2)
        #expect(item.severity == 2)
        #expect(item.criteriaDecision == CriteriaDecision.exceedsThreshold.rawValue)
        #expect(item.decisionConfirmedBy == "홍길동")
        #expect(item.decisionConfirmedAt == when)
    }

    @Test("사후 스냅샷은 항목의 1:N 개선조치를 전부 담당·기한·상태·이행일·개선후위험도·효과확인까지 보존한다")
    func postSnapshotPreservesAllCorrectiveActions() throws {
        let ctx = try makeContext()
        let ra = try startedWithItems(in: ctx)
        let item = try addItem(ra, likelihood: 3, severity: 3, level: .high,
                               task: "굴착", hazard: "붕괴", sortOrder: 0, in: ctx)
        let due = Date(timeIntervalSince1970: 1_700_900_000)

        let a1 = try CorrectiveActionEditing.add(to: item, in: ra, measure: "흙막이 보강",
                                                 responsibleName: "김담당", dueDate: due,
                                                 at: when, context: ctx)
        try CorrectiveActionEditing.update(a1, in: ra, measure: "흙막이 보강",
                                           responsibleName: "김담당", dueDate: due,
                                           status: .completed, implementedAt: when,
                                           postRiskLevel: .low, at: when, context: ctx)
        try CorrectiveActionEditing.confirmEffectiveness(a1, in: ra, result: .effective,
                                                         by: "박확인", at: when, context: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "관리감독자 배치",
                                        at: when, context: ctx)

        let snap = try SharingEventPolicy.makeSnapshot(phase: .post, for: ra)
        let snapItem = try #require(snap.items.first)
        #expect(snapItem.correctiveActions.count == 2)   // 1:N 전부 — 문자열 축약 금지

        let done = try #require(snapItem.correctiveActions.first { $0.measure == "흙막이 보강" })
        #expect(done.responsibleName == "김담당")
        #expect(done.dueDate == due)
        #expect(done.status == CorrectiveActionStatus.completed.rawValue)
        #expect(done.implementedAt == when)
        #expect(done.postRiskLevel == RiskLevel.low.rawValue)
        #expect(done.effectivenessResult == EffectivenessResult.effective.rawValue)
        #expect(done.confirmedBy == "박확인")
        #expect(done.effectivenessConfirmedAt == when)

        let planned = try #require(snapItem.correctiveActions.first { $0.measure == "관리감독자 배치" })
        #expect(planned.status == CorrectiveActionStatus.notStarted.rawValue)
        #expect(planned.implementedAt == nil)
        #expect(planned.effectivenessResult == nil)
    }

    // MARK: - 결정적 정렬 · key 정렬 · 날짜 고정

    @Test("항목은 sortOrder, 조치는 id 기준으로 결정적으로 정렬된다")
    func snapshotOrderingIsDeterministic() throws {
        let ctx = try makeContext()
        let ra = try startedWithItems(in: ctx)
        // 삽입 순서를 sortOrder와 반대로 — 스냅샷은 sortOrder를 따라야 한다.
        try addItem(ra, likelihood: 1, severity: 1, level: .low,
                    task: "세번째", hazard: "h3", sortOrder: 2, in: ctx)
        try addItem(ra, likelihood: 1, severity: 1, level: .low,
                    task: "첫번째", hazard: "h1", sortOrder: 0, in: ctx)
        try addItem(ra, likelihood: 1, severity: 1, level: .low,
                    task: "두번째", hazard: "h2", sortOrder: 1, in: ctx)

        let snap = try SharingEventPolicy.makeSnapshot(phase: .post, for: ra)
        #expect(snap.items.map(\.taskDescription) == ["첫번째", "두번째", "세번째"])

        // 조치 정렬은 CorrectiveActionPolicy.sortedCorrectiveActions 와 동일한 id 기준.
        let item = try #require(ra.items?.first { $0.sortOrder == 0 })
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "A", at: when, context: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "B", at: when, context: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "C", at: when, context: ctx)

        let snap2 = try SharingEventPolicy.makeSnapshot(phase: .post, for: ra)
        let ids = try #require(snap2.items.first).correctiveActions.map(\.actionId.uuidString)
        #expect(ids == ids.sorted())
        let expected = CorrectiveActionPolicy.sortedCorrectiveActions(item).map(\.id)
        #expect(try #require(snap2.items.first).correctiveActions.map(\.actionId) == expected)
    }

    @Test("같은 상태를 두 번 인코딩하면 완전히 동일한 JSON이 나온다 (key 정렬 고정)")
    func encodingIsByteStable() throws {
        let ctx = try makeContext()
        let ra = try startedWithItems(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium,
                               task: "용접", hazard: "화재", sortOrder: 0, in: ctx)
        try CorrectiveActionEditing.add(to: item, in: ra, measure: "불티방지포", at: when, context: ctx)

        let a = try SharingEventPolicy.makeSnapshotJSON(phase: .post, for: ra)
        let b = try SharingEventPolicy.makeSnapshotJSON(phase: .post, for: ra)
        #expect(a == b)

        // key 정렬: 최상위 키가 사전순으로 나타난다.
        let assessmentIdx = try #require(a.range(of: "\"assessmentId\"")).lowerBound
        let formatIdx = try #require(a.range(of: "\"formatVersion\"")).lowerBound
        let siteIdx = try #require(a.range(of: "\"siteName\"")).lowerBound
        #expect(assessmentIdx < formatIdx)
        #expect(formatIdx < siteIdx)
    }

    @Test("날짜는 ISO8601 고정 인코딩이며 로케일·타임존에 흔들리지 않는다")
    func datesUseFixedEncoding() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        let json = try SharingEventPolicy.makeSnapshotJSON(phase: .pre, for: ra)
        // 1_700_600_000 = 2023-11-21T20:53:20Z
        #expect(json.contains("2023-11-21T20:53:20Z"))
    }

    // MARK: - 개인정보·바이너리 배제

    @Test("스냅샷에는 증거사진 binary도 참여자 개인정보도 중복 저장되지 않는다")
    func snapshotExcludesPhotosAndParticipants() throws {
        let ctx = try makeContext()
        let ra = try startedWithItems(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium,
                               task: "도장", hazard: "유기용제", sortOrder: 0, in: ctx)
        let photo = Data(repeating: 0xAB, count: 64)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "국소배기",
                                                     at: when, context: ctx)
        try CorrectiveActionEditing.update(action, in: ra, measure: "국소배기", status: .inProgress,
                                           evidencePhotoData: photo, at: when, context: ctx)
        let participant = RiskAssessmentParticipant(name: "참여자비밀", role: .worker)
        participant.riskAssessment = ra
        ctx.insert(participant)
        ra.participants = (ra.participants ?? []) + [participant]
        try ctx.save()

        let json = try SharingEventPolicy.makeSnapshotJSON(phase: .post, for: ra)
        #expect(!json.contains("참여자비밀"))
        #expect(!json.contains(photo.base64EncodedString()))
        #expect(!json.lowercased().contains("photo"))
        #expect(!json.lowercased().contains("participant"))
    }

    // MARK: - 불변성 (원본 수정·삭제 후에도 당시 스냅샷은 변하지 않는다)

    @Test("원본 항목·조치를 나중에 바꿔도 이미 만든 스냅샷 JSON은 변하지 않는다")
    func snapshotIsImmutableAgainstLaterEdits() throws {
        let ctx = try makeContext()
        let ra = try startedWithItems(in: ctx)
        let item = try addItem(ra, likelihood: 2, severity: 2, level: .medium,
                               task: "원래작업", hazard: "원래위험", sortOrder: 0, in: ctx)
        let action = try CorrectiveActionEditing.add(to: item, in: ra, measure: "원래대책",
                                                     at: when, context: ctx)

        let captured = try SharingEventPolicy.makeSnapshotJSON(phase: .post, for: ra)

        // 원본을 수정하고 조치를 삭제한다.
        item.taskDescription = "바뀐작업"
        try CorrectiveActionEditing.remove(action, in: ra, at: when, context: ctx)
        try ctx.save()

        // 값 복사이므로 이전에 캡처한 JSON은 그대로다.
        #expect(captured.contains("원래작업"))
        #expect(captured.contains("원래대책"))
        #expect(!captured.contains("바뀐작업"))
        let decoded = try SharingSnapshot.decode(captured)
        #expect(decoded.items.first?.taskDescription == "원래작업")
        #expect(decoded.items.first?.correctiveActions.count == 1)
    }

    // MARK: - fail-closed decode

    @Test("손상 JSON은 fail-closed — 현재 데이터로 대체하지 않고 오류를 던진다")
    func corruptSnapshotFailsClosed() {
        #expect(throws: (any Error).self) { try SharingSnapshot.decode("") }
        #expect(throws: (any Error).self) { try SharingSnapshot.decode("{ not json") }
        #expect(throws: (any Error).self) { try SharingSnapshot.decode("{\"formatVersion\":1}") }
        #expect(throws: (any Error).self) {
            try SharingSnapshot.decode("[{\"formatVersion\":1}]")
        }
    }

    @Test("미래 formatVersion은 fail-closed로 거부한다 (조용히 읽지 않는다)")
    func futureFormatVersionFailsClosed() throws {
        let ctx = try makeContext()
        let ra = try plannedAssessment(in: ctx)
        let json = try SharingEventPolicy.makeSnapshotJSON(phase: .pre, for: ra)
        let bumped = json.replacingOccurrences(
            of: "\"formatVersion\":\(SharingSnapshot.currentFormatVersion)",
            with: "\"formatVersion\":\(SharingSnapshot.currentFormatVersion + 1)")
        #expect(bumped != json)

        #expect(throws: SharingSnapshotError.unsupportedFormatVersion) {
            try SharingSnapshot.decode(bumped)
        }
    }
}
