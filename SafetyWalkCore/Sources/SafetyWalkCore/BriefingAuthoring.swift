import Foundation
import SwiftData

/// 브리핑 생성 입력 — 화면이 모은 값을 담는 **순수 값 타입** (`AssessmentDraft` 와 같은 이유:
/// SwiftData 를 모르므로 ViewModel 이 자유롭게 조립하고, Core 가 한 번에 검증·영속한다).
///
/// Site 는 필수(TBM_0_ARCH §2 "Site 필수 소속"); Area·Program·Assessment 는 선택 — 값이 있으면
/// UUID 로만 참조되고 관계는 아니므로(SCHEMA_V3 §5), 원본이 나중에 지워져도 이 브리핑은 살아남는다.
public struct BriefingDraft: Equatable, Sendable {
    public var siteId: UUID
    public var siteName: String
    public var areaId: UUID?
    public var programId: UUID?
    public var assessmentId: UUID?
    public var briefingProfile: BriefingProfileCode?
    public var taskDescription: String
    public var occurredAt: Date?
    public var location: String
    public var ownerName: String?

    public init(siteId: UUID, siteName: String, areaId: UUID? = nil, programId: UUID? = nil,
                assessmentId: UUID? = nil, briefingProfile: BriefingProfileCode? = nil,
                taskDescription: String = "", occurredAt: Date? = nil, location: String = "",
                ownerName: String? = nil) {
        self.siteId = siteId
        self.siteName = siteName
        self.areaId = areaId
        self.programId = programId
        self.assessmentId = assessmentId
        self.briefingProfile = briefingProfile
        self.taskDescription = taskDescription
        self.occurredAt = occurredAt
        self.location = location
        self.ownerName = ownerName
    }
}

/// 브리핑 생성이 거부된 이유. 영속 오류는 store·메모리 원복 후 원래 오류로 재전파된다.
public enum BriefingAuthoringError: Error, Equatable {
    case emptySiteName
}

/// 브리핑 생성의 **단일 원자 연산** (WO LEGAL-TBM-1 §2.1, `AssessmentAuthoring.create` 와 같은
/// 형태). 결과는 항상 `.draft` — `SafetyBriefing.init` 에 `status` 인자가 없어 다른 상태로 태어날
/// 수 없다. 시작(conduct)·확정(finalize)·취소(cancel)는 `BriefingLifecycle` 이 따로 수행한다.
///
/// 원자성: 검증이 context 를 건드리기 전에 끝나므로, insert 이후 실패할 수 있는 것은 commit 뿐이다.
/// commit 이 실패하면 삽입한 브리핑을 지운 뒤 rollback 해 store·메모리 어디에도 남기지 않는다.
public enum BriefingAuthoring {

    @discardableResult
    public static func create(
        _ draft: BriefingDraft,
        in context: ModelContext
    ) throws -> SafetyBriefing {
        try create(draft, in: context, commit: { try context.save() })
    }

    /// Testing seam for the commit step (같은 이유: unique 없는 CloudKit 모델은 `save()` 를 catch
    /// 가능한 실패로 만들 수 없다). Not public.
    @discardableResult
    static func create(
        _ draft: BriefingDraft,
        in context: ModelContext,
        commit: () throws -> Void
    ) throws -> SafetyBriefing {
        try validate(draft)

        let briefing = SafetyBriefing(
            siteId: draft.siteId,
            siteName: draft.siteName.trimmed,
            programId: draft.programId,
            assessmentId: draft.assessmentId,
            areaId: draft.areaId,
            briefingProfile: draft.briefingProfile,
            taskDescription: draft.taskDescription.trimmed,
            occurredAt: draft.occurredAt,
            location: draft.location.trimmed,
            ownerName: draft.ownerName?.trimmedOrNil)
        context.insert(briefing)

        do {
            try commit()
        } catch {
            context.delete(briefing)
            context.rollback()
            throw error
        }
        return briefing
    }

    // MARK: - Validation (context 를 건드리기 전에 전부 끝낸다)

    private static func validate(_ draft: BriefingDraft) throws {
        guard !draft.siteName.sw_isBlank else { throw BriefingAuthoringError.emptySiteName }
    }
}
