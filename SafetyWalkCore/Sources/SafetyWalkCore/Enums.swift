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
