import Foundation
import SwiftData

/// 평가 삭제의 원자 연산 (WO LEGAL-2e). `RiskAssessment` 는 cascade+inverse(criteria·items·
/// participants·sharingEvents, SCHEMA_V3 §5)를 선언하므로 자식은 SwiftData 가 함께 지운다 — 이
/// 타입이 손수 끊을 관계가 없다(다른 SwiftData 관계가 이 루트를 가리키지도 않는다 — Program/Site
/// 참조는 값 스냅샷일 뿐 관계가 아니다, SCHEMA_V3 §5).
///
/// 보존 경고는 여기서 강제하지 않는다 — 화면이 `RetentionPolicy` 를 읽어 확인 절차에 경고를 얹고,
/// 사용자가 확인하면 이 연산을 호출한다(CLAUDE.md No legal judgment: 삭제를 막는 것은 Core 가 아니라
/// 사용자 확인이다).
///
/// ⚠️ 알려진 툴체인 위험(재현 확인, 이 WO 가 만든 결함 아님): 이 SDK(Swift 6.3 / macOS 26)에서
/// `commit()` 이 실패해 `context.rollback()` 을 호출할 때, 대기 중인 cascade 삭제가
/// `AssessmentCriteria`·`SharingEvent`(또는 item 을 거친 `CorrectiveAction`)를 건드리면 SwiftData 가
/// "Unexpected backing data for snapshot creation" 로 **크래시**한다. 순수 `context.delete`/`rollback`
/// 만으로도 재현되고, 이미 병합된 `AssessmentItemEditing.remove`(개선조치 있는 항목의 삭제 실패 시)도
/// 동일하게 재현된다 — delete+rollback 관용구 전체에 걸린 프레임워크 결함이며 이 타입의 로직 문제가
/// 아니다. 실무 영향은 낮다(이 CloudKit 모델들은 `.unique` 가 없어 `save()` 가 사실상 catch 가능하게
/// 실패하지 않는다 — 다른 Core 원자 연산의 testing seam 주석 참고). `AssessmentDeletionTests` 는 이
/// 크래시를 피해 items·participants 조합으로만 rollback 을 검증한다.
public enum AssessmentDeletion {

    public static func delete(_ assessment: RiskAssessment, in context: ModelContext) throws {
        try delete(assessment, in: context, commit: { try context.save() })
    }

    /// Testing seam for the commit step (같은 이유: unique 없는 CloudKit 모델은 `save()` 를 catch
    /// 가능한 실패로 만들 수 없다). Not public.
    static func delete(_ assessment: RiskAssessment, in context: ModelContext,
                       commit: () throws -> Void) throws {
        context.delete(assessment)
        do {
            try commit()
        } catch {
            context.rollback()
            throw error
        }
    }
}
