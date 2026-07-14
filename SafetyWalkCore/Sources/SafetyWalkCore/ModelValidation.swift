import Foundation

/// Business-rule validation errors for the V3 models (SCHEMA_V3 §4.1). CloudKit forces a
/// stored default on every attribute, so a defaulted `""`/`nil` can never satisfy a business
/// "필수" rule on its own. `validate()` re-checks those rules and must be called before
/// insert/finalize so an empty/incomplete model is never persisted (SCHEMA_V3 §4.1 —
/// "insert/finalize 전 검증 실패 시 저장 금지", LEGAL-0 save()-throws 패턴 확장).
public enum ModelValidationError: Error, Equatable {
    case emptyName            // 참여자 이름 필수
    case emptySiteName        // 현장명 스냅샷 필수
    case missingSite          // siteId 필수
    case missingJurisdiction  // 법적 관할 필수
    case missingPhase         // 공유 시점 필수
    case missingMethod        // 공유 방법 필수
    case missingSharedAt      // 공유 시각 필수
}

extension String {
    /// True when the string is empty or only whitespace — the "미기록" case for a required
    /// business string that CloudKit defaulted to "".
    var sw_isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
