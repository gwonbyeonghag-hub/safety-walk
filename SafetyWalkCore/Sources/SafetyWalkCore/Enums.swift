import Foundation

// All domain enums. Names are canonical — see DOMAIN_TERMS.md before renaming.

public enum ChecklistItemResult: String, Codable, CaseIterable, Hashable {
    case pass
    case fail
    case notApplicable
    case unchecked
}

public enum RiskLevel: String, Codable, CaseIterable, Hashable, Comparable {
    case low
    case medium
    case high

    private static let order: [RiskLevel] = [.low, .medium, .high]

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

public enum CorrectiveActionStatus: String, Codable, CaseIterable, Hashable {
    case notStarted
    case inProgress
    case completed
}

public enum InspectionStatus: String, Codable, Hashable {
    case inProgress
    case completed
}

public enum RegionProfile: String, Codable, CaseIterable, Hashable {
    case korea
    case global
}

public enum HazardType: String, Codable, CaseIterable, Hashable {
    case fallRisk
    case electrical
    case fire
    case chemical
    case general
    case other
}

// Local app-appearance preference (Settings → Appearance). Persisted by raw
// String via @AppStorage; not a SwiftData model. Mapping to SwiftUI's
// `ColorScheme?` lives in SafetyWalkApp.swift to keep this file SwiftUI-free.
public enum AppearanceMode: String, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    public var id: String { rawValue }
}

// MARK: - Risk Assessment (위험성평가) — see DOMAIN_TERMS.md

/// 평가종류: 최초 / 정기(≥연1회) / 수시.
public enum RiskAssessmentKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case initial      // 최초
    case regular      // 정기
    case occasional   // 수시

    public var id: String { rawValue }
}

/// 평가기법 (4종 — V2_ROADMAP AD-3).
public enum RiskAssessmentMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case threeLevel          // 3단계 (상·중·하 직접 선택)
    case frequencySeverity   // 빈도×강도 (가능성 1–3 × 중대성 1–3 → 점수 → 밴드)
    case checklist           // 체크리스트법 (완료 점검의 부적합 항목 연계; 위험성=3단계 직접)
    case jsa                 // JSA/JHA (해외) — 순서 있는 작업단계; 위험성=빈도×강도

    public var id: String { rawValue }

    /// Risk is entered as a likelihood×severity score (true) vs. a direct 상/중/하 level
    /// (false). Centralizes the input/derivation branch shared by the editor, the
    /// view model's resolution, and the detail breakdown.
    public var usesFrequencySeverity: Bool {
        switch self {
        case .frequencySeverity, .jsa: return true
        case .threeLevel, .checklist:  return false
        }
    }
}

// MARK: - SCHEMA_V3 §3 — 위험성평가/공유/브리핑 공유·신규 enum
// nil은 "미기록"을 의미하는 optional 필드에서만 쓰인다(교정 #3). 표시 문자열은
// 로컬라이즈에서 생성 — raw-code enum은 안정 저장값(교정 #6).

/// 평가·브리핑 참여자 역할.
public enum ParticipantRole: String, Codable, CaseIterable, Identifiable, Hashable {
    case worker      // 근로자
    case workerRep   // 근로자대표

    public var id: String { rawValue }
}

/// 참여/서명 확인 방법. nil=미확인(교정 #3).
public enum ConfirmationMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case managerRecord  // 관리자 기록
    case selfConfirm    // 본인 확인
    case signature      // 서명

    public var id: String { rawValue }
}

/// 위험성평가 진행 상태.
public enum AssessmentStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case planned
    case inProgress
    case finalized
    case cancelled

    public var id: String { rawValue }
}

/// TBM/브리핑 진행 상태.
public enum BriefingStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case draft
    case conducted
    case finalized
    case cancelled

    public var id: String { rawValue }
}

/// 평가 참여 방법(평가 전용 — 순회/면담/설문/기타). nil=미기록.
public enum AssessmentParticipationMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case patrol      // 순회
    case interview   // 면담
    case survey      // 설문
    case other       // 기타

    public var id: String { rawValue }
}

/// 비TBM 공유 방법(교육/게시/서면/전자).
public enum SharingMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case education   // 교육
    case posting     // 게시
    case written     // 서면
    case electronic  // 전자

    public var id: String { rawValue }
}

/// 상시 여부.
public enum OperatingMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case regular      // 정기/일반
    case continuous   // 상시

    public var id: String { rawValue }
}

/// 프로그램 상태(물리삭제 대신 archived).
public enum ProgramStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case active
    case archived

    public var id: String { rawValue }
}

/// 허용기준 대비 결정. nil=미평가; 초과 여부는 사용자 확인(교정 #3).
public enum CriteriaDecision: String, Codable, CaseIterable, Identifiable, Hashable {
    case withinThreshold   // 기준 이내
    case exceedsThreshold  // 기준 초과

    public var id: String { rawValue }
}

/// 근로자대표 참여 상태. nil=미기록(교정 #3).
public enum WorkerRepStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case notRequested             // 미요청
    case requestedNotParticipated // 요청·미참여
    case participated             // 참여

    public var id: String { rawValue }
}

/// 공유 시점(사전/사후). nil=미설정(교정 #3).
public enum SharingPhase: String, Codable, CaseIterable, Identifiable, Hashable {
    case pre    // 사전
    case post   // 사후

    public var id: String { rawValue }
}

/// 개선조치 효과확인 결과. nil=미확인 — "효과확인됨"은 result≠nil로 파생(Bool 아님, 교정 #2).
public enum EffectivenessResult: String, Codable, CaseIterable, Identifiable, Hashable {
    case effective          // 효과 있음
    case partiallyEffective // 부분 효과
    case ineffective        // 효과 없음

    public var id: String { rawValue }
}

/// 법적 관할 — RegionProfile(언어-지역)과 별개, 혼용 금지(교정 #6).
public enum JurisdictionCode: String, Codable, CaseIterable, Identifiable, Hashable {
    case kr
    case us

    public var id: String { rawValue }
}

/// 업종 프로필 코드(교정 #6).
public enum IndustryProfileCode: String, Codable, CaseIterable, Identifiable, Hashable {
    case general
    case construction
    case electric

    public var id: String { rawValue }
}

/// 브리핑 프로필 코드(교정 #6).
public enum BriefingProfileCode: String, Codable, CaseIterable, Identifiable, Hashable {
    case krTBM
    case usCAConstruction
    case usElectric
    case usGeneral

    public var id: String { rawValue }
}
