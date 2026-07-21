import Foundation
import SwiftData

/// 한 평가의 통합 공유 이력 한 건 — TBM 공유(확정된 `SafetyBriefing`) 또는 비TBM 공유
/// (`SharingEvent`). TBM 은 별도 `SharingEvent` 를 만들지 않으므로(SCHEMA_V3 §5·TBM_0_ARCH §8
/// "이중 저장 제거") 이 타입이 두 출처를 하나의 시간순 이력으로 합치는 유일한 지점이다.
public enum UnifiedSharingHistoryEntry: Identifiable, Sendable {
    case briefing(SafetyBriefing)
    case sharingEvent(SharingEvent)

    public var id: UUID {
        switch self {
        case .briefing(let b):     return b.id
        case .sharingEvent(let e): return e.id
        }
    }

    /// 정렬 기준 시각 — TBM 은 확정 순간이 공유 증명이 되는 순간이므로 `finalizedAt`(사후 공유와 같은
    /// 성격, WO LEGAL-TBM-1 §2 "확정된 SafetyBriefing 자체가 TBM 방식의 공유 증명"), 비TBM 은 `sharedAt`.
    public var date: Date? {
        switch self {
        case .briefing(let b):     return b.finalizedAt
        case .sharingEvent(let e): return e.sharedAt
        }
    }
}

/// 통합 공유 이력 조회 — SCHEMA_V3 §5 · TBM_0_ARCH §8 (WO LEGAL-TBM-3 §2). 읽기 전용이며 아무것도
/// 변이하지 않는다: `SafetyBriefing`(TBM, `.finalized` 만 — draft/conducted/cancelled 는 아직 공유
/// 증명이 아니다) + `SharingEvent`(비TBM, `assessment.sharingEvents`)를 하나의 시간순 이력으로
/// 합쳐 반환한다.
///
/// `briefing.assessmentId` 는 관계가 아니라 값 UUID(cascade 없음, SCHEMA_V3 §5) 라서
/// `assessment.briefings` 같은 역참조가 없다 — 그래서 `ModelContext` 로 직접 조회한다(Core 안에서
/// 새 fetch 를 실행하는 것은 원자 연산들도 이미 하는 것과 같은 패턴이며, 이 조회는 아무것도
/// insert/delete/save 하지 않는다).
public enum UnifiedSharingHistory {

    /// `assessment` 하나의 통합 이력 — 최근 순(시간 역순). 동시각은 `id` 로 안정 정렬해 화면·PDF·
    /// 테스트가 늘 같은 순서를 본다(`SharingEventPolicy.sortedEvents` 와 같은 관례).
    public static func entries(for assessment: RiskAssessment, in context: ModelContext) -> [UnifiedSharingHistoryEntry] {
        let assessmentId = assessment.id
        let briefings = (try? context.fetch(FetchDescriptor<SafetyBriefing>(
            predicate: #Predicate<SafetyBriefing> { $0.assessmentId == assessmentId }
        ))) ?? []
        let finalizedBriefings = briefings.filter { $0.status == .finalized }

        let combined: [UnifiedSharingHistoryEntry] =
            finalizedBriefings.map { .briefing($0) } + SharingEventPolicy.sortedEvents(assessment).map { .sharingEvent($0) }

        return combined.sorted { lhs, rhs in
            let l = lhs.date ?? .distantPast
            let r = rhs.date ?? .distantPast
            return l != r ? l > r : lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
