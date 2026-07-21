import Foundation
import SwiftData

/// `SafetyBriefing.assessmentId` 는 관계가 아니라 값 UUID(cascade 없음, SCHEMA_V3 §5) — 그래서
/// 연결된 `RiskAssessment` 를 읽으려면 매번 조회가 필요하다. iOS 상세 화면과 Mac 조회 화면이 각자
/// 똑같은 fetch 를 만들지 않도록 한 곳에 둔다(WO LEGAL-TBM-3 code-review 반영).
public enum BriefingAssessmentLink {

    /// `briefing.assessmentId` 가 가리키는 평가, 없거나 못 찾으면 nil. 읽기 전용 — 아무것도
    /// 변이하지 않는다.
    public static func resolve(_ briefing: SafetyBriefing, in context: ModelContext) -> RiskAssessment? {
        guard let targetId = briefing.assessmentId else { return nil }
        let descriptor = FetchDescriptor<RiskAssessment>(
            predicate: #Predicate<RiskAssessment> { $0.id == targetId })
        return try? context.fetch(descriptor).first
    }
}
