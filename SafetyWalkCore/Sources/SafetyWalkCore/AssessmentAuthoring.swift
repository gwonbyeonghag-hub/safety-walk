import Foundation
import SwiftData

/// 법적 관할 판단 — `RegionProfile`(언어·지역 콘텐츠 축)과 **별개**이며 서로를 유도하지 않는다
/// (DOMAIN_TERMS). 프로파일은 **추천만** 하고, 실제 관할은 사용자가 확인한 값만 기록된다.
public enum JurisdictionPolicy {

    /// 지역 프로파일이 제시하는 **추천값**. 이 값이 자동으로 저장되면 안 된다 — 화면은 이를 제안으로만
    /// 보여주고, 사용자가 고른 값이 `AssessmentDraft.jurisdiction` 에 들어간다(WO LEGAL-2d-PATH §3).
    public static func suggested(for profile: RegionProfile) -> JurisdictionCode {
        switch profile {
        case .korea:  return .kr
        case .global: return .us
        }
    }

    /// KR 은 시행규칙 제37조의3 사전(일정) 공유가 시작의 전제이므로 **일정이 필수**다. US·미설정은 선택.
    /// 저장 버튼 활성화와 Core 검증이 공유하는 단일 소스.
    public static func requiresSchedule(_ jurisdiction: JurisdictionCode?) -> Bool {
        jurisdiction == .kr
    }

    /// US 는 업종 범위(General Industry vs Construction 등) 없이 저장할 수 없다 — 위험 임계값이
    /// 업종마다 달라 범위 없는 US 기록은 어떤 기준을 참조했는지 알 수 없다(WO LEGAL-3A, P0-3/P0-6).
    /// KR·미설정은 업종을 요구하지 않으며 지역 프로파일·언어로 자동 확정되지도 않는다. 저장 버튼
    /// 활성화와 Core 검증이 공유하는 단일 소스(`requiresSchedule` 과 같은 패턴).
    public static func requiresIndustry(_ jurisdiction: JurisdictionCode?) -> Bool {
        jurisdiction == .us
    }
}

/// 평가 생성 입력 — 화면이 모은 값을 담는 **순수 값 타입**. SwiftData 를 모르므로 ViewModel 이 자유롭게
/// 조립하고, Core 가 한 번에 검증·영속한다.
public struct AssessmentDraft: Equatable, Sendable {
    public var kind: RiskAssessmentKind
    public var method: RiskAssessmentMethod
    public var siteId: UUID
    public var siteName: String
    public var assessorName: String
    public var note: String?
    public var linkedInspectionId: UUID?
    /// **사용자가 확인한** 관할. 기본값은 `nil`(미설정) — 프로파일 추천이 자동으로 채우지 않는다.
    public var jurisdiction: JurisdictionCode?
    /// **사용자가 확인한** 업종 범위. US 관할은 필수(`JurisdictionPolicy.requiresIndustry`), KR·미설정은
    /// 요구되지 않으며 지역 프로파일·언어로 자동 확정되지도 않는다(WO LEGAL-3A).
    public var industryProfile: IndustryProfileCode?
    public var scheduledAt: Date?
    public var items: [ItemDraft]

    public init(kind: RiskAssessmentKind, method: RiskAssessmentMethod,
                siteId: UUID, siteName: String, assessorName: String,
                note: String? = nil, linkedInspectionId: UUID? = nil,
                jurisdiction: JurisdictionCode? = nil, industryProfile: IndustryProfileCode? = nil,
                scheduledAt: Date? = nil,
                items: [ItemDraft] = []) {
        self.kind = kind
        self.method = method
        self.siteId = siteId
        self.siteName = siteName
        self.assessorName = assessorName
        self.note = note
        self.linkedInspectionId = linkedInspectionId
        self.jurisdiction = jurisdiction
        self.industryProfile = industryProfile
        self.scheduledAt = scheduledAt
        self.items = items
    }

    /// 한 항목의 초기 입력. `measure` 가 있을 때만 개선조치가 하나 만들어진다(빈 조치 양산 금지).
    public struct ItemDraft: Equatable, Sendable {
        public var taskDescription: String
        public var hazardDescription: String
        public var currentControls: String?
        public var likelihood: Int?
        public var severity: Int?
        /// 해결된 위험성 수준. **nil = 미평가이며 저장할 수 없다**(자동 Low 금지, 교정 #3).
        public var riskLevel: RiskLevel?
        public var linkedHazardId: UUID?
        public var measure: String?
        public var responsibleName: String?
        public var dueDate: Date?

        public init(taskDescription: String, hazardDescription: String,
                    currentControls: String? = nil, likelihood: Int? = nil, severity: Int? = nil,
                    riskLevel: RiskLevel? = nil, linkedHazardId: UUID? = nil,
                    measure: String? = nil, responsibleName: String? = nil, dueDate: Date? = nil) {
            self.taskDescription = taskDescription
            self.hazardDescription = hazardDescription
            self.currentControls = currentControls
            self.likelihood = likelihood
            self.severity = severity
            self.riskLevel = riskLevel
            self.linkedHazardId = linkedHazardId
            self.measure = measure
            self.responsibleName = responsibleName
            self.dueDate = dueDate
        }
    }
}

/// 평가 생성이 거부된 이유. 영속 오류는 store·메모리 원복 후 원래 오류로 재전파된다.
public enum AssessmentAuthoringError: Error, Equatable {
    case emptySiteName
    case emptyAssessorName
    case emptyTaskDescription
    case emptyHazardDescription
    case unassessedItem                     // 위험성 수준 미입력 — 미평가는 저장하지 않는다
    case missingScheduleForJurisdiction     // KR 인데 일정 없음
    case missingIndustryForJurisdiction     // US 인데 업종 범위 없음 (WO LEGAL-3A)
    case incompleteAction                   // 담당/기한만 있고 감소대책이 비어 있음
}

/// 평가 생성의 **단일 원자 연산** (WO LEGAL-2d-PATH §4).
///
/// 두 진입 경로가 이 하나를 공유한다 — "새 평가"(항목 포함)와 "평가 계획"(헤더만, `items: []`).
/// 어느 쪽이든 결과는 **항상 `.planned`** 이며, 시작(기준 잠금 + `.inProgress`)은 상세 화면에서
/// `AssessmentStart.start` 가 따로 수행한다. 저장하자마자 시작하던 옛 경로는 제거됐다(§2).
///
/// 원자성: **모든 검증이 context 를 건드리기 전에** 끝나므로, insert 이후 실패할 수 있는 것은 commit
/// 뿐이다. commit 이 실패하면 관계를 끊고 삽입한 객체를 지운 뒤 rollback 해 **store 와 메모리 어디에도**
/// 평가·항목·조치가 남지 않는다.
public enum AssessmentAuthoring {

    @discardableResult
    public static func create(
        _ draft: AssessmentDraft,
        now: Date,
        in context: ModelContext
    ) throws -> RiskAssessment {
        try create(draft, now: now, in: context, commit: { try context.save() })
    }

    /// Testing seam for the commit step (같은 이유: unique 없는 CloudKit 모델은 `save()` 를 catch 가능한
    /// 실패로 만들 수 없다). Not public.
    @discardableResult
    static func create(
        _ draft: AssessmentDraft,
        now: Date,
        in context: ModelContext,
        commit: () throws -> Void
    ) throws -> RiskAssessment {
        try validate(draft)

        let assessment = RiskAssessment(
            kind: draft.kind,
            method: draft.method,
            siteId: draft.siteId,
            siteName: draft.siteName.trimmed,
            assessorName: draft.assessorName.trimmed,
            note: draft.note?.trimmedOrNil,
            linkedInspectionId: draft.linkedInspectionId,
            jurisdictionSnapshot: draft.jurisdiction,     // 사용자가 확인한 값만 값 복사
            industryProfileSnapshot: draft.industryProfile,
            scheduledAt: draft.scheduledAt)
        context.insert(assessment)

        var items: [RiskAssessmentItem] = []
        var actions: [CorrectiveAction] = []
        for (index, d) in draft.items.enumerated() {
            let item = RiskAssessmentItem(
                taskDescription: d.taskDescription.trimmed,
                hazardDescription: d.hazardDescription.trimmed,
                currentControls: d.currentControls?.trimmedOrNil,
                likelihood: draft.method.usesFrequencySeverity ? d.likelihood : nil,
                severity: draft.method.usesFrequencySeverity ? d.severity : nil,
                riskLevel: d.riskLevel,
                linkedHazardId: d.linkedHazardId,
                sortOrder: index)
            // criteriaDecision 은 여기서 채우지 않는다 — 기준 이내/초과는 시작 후 사용자가 확인한다.
            context.insert(item)
            item.riskAssessment = assessment
            items.append(item)

            if let measure = d.measure?.trimmedOrNil {
                // 생성 관문을 그대로 사용 — 모델 생성자는 패키지 밖에 없다. 평가가 아직 `.planned` 라
                // `CorrectiveActionEditing.add`(inProgress/finalized 전용)는 쓸 수 없다.
                let action = try CorrectiveActionPolicy.makeDraft(
                    item: item, measure: measure,
                    responsibleName: d.responsibleName?.trimmedOrNil, dueDate: d.dueDate)
                context.insert(action)
                actions.append(action)
            }
        }
        assessment.items = items

        do {
            try commit()
        } catch {
            // rollback 은 store 만 되돌린다 — 메모리 관계가 살아 있으면 SwiftData 가 다시 동기화하므로
            // inverse 를 먼저 끊고 삽입한 객체를 지운다(`CorrectiveActionEditing.add` 패턴).
            for action in actions {
                action.item = nil
                context.delete(action)
            }
            for item in items {
                item.riskAssessment = nil
                item.correctiveActions = []
                context.delete(item)
            }
            assessment.items = []
            context.delete(assessment)
            context.rollback()
            throw error
        }
        return assessment
    }

    // MARK: - Validation (context 를 건드리기 전에 전부 끝낸다)

    private static func validate(_ draft: AssessmentDraft) throws {
        guard !draft.siteName.sw_isBlank else { throw AssessmentAuthoringError.emptySiteName }
        guard !draft.assessorName.sw_isBlank else { throw AssessmentAuthoringError.emptyAssessorName }
        if JurisdictionPolicy.requiresSchedule(draft.jurisdiction), draft.scheduledAt == nil {
            throw AssessmentAuthoringError.missingScheduleForJurisdiction
        }
        if JurisdictionPolicy.requiresIndustry(draft.jurisdiction), draft.industryProfile == nil {
            throw AssessmentAuthoringError.missingIndustryForJurisdiction
        }
        for d in draft.items {
            guard !d.taskDescription.sw_isBlank else { throw AssessmentAuthoringError.emptyTaskDescription }
            guard !d.hazardDescription.sw_isBlank else { throw AssessmentAuthoringError.emptyHazardDescription }
            guard d.riskLevel != nil else { throw AssessmentAuthoringError.unassessedItem }
            // 담당·기한만 채우고 감소대책이 비면 조치를 조용히 버리는 대신 저장을 막는다(LEGAL-2c).
            if d.measure?.trimmedOrNil == nil,
               d.responsibleName?.trimmedOrNil != nil || d.dueDate != nil {
                throw AssessmentAuthoringError.incompleteAction
            }
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedOrNil: String? { trimmed.isEmpty ? nil : trimmed }
}
