import Foundation

/// `templateId` → 미국 Federal 점검 템플릿 범위 판단 — 화면마다 흩어진 문자열 판별(`hasPrefix` 등)을
/// 막는 단일 공유 정책 지점(`JurisdictionPolicy` 와 같은 패턴, WO LEGAL-3B §E).
///
/// `Inspection.templateId` 는 생성 시점 값의 불변 스냅샷이므로, 템플릿이 나중에 추가·개정돼도 과거
/// 기록의 판정은 그 기록이 실제로 쓴 versioned id 그대로 유지된다.
public enum ChecklistTemplatePolicy {

    /// 정확한 versioned id → 산업 범위. 새 US Federal 템플릿이 추가되면 이 스위치만 늘어난다.
    public static func usFederalScope(forTemplateId templateId: String) -> ChecklistIndustryScope? {
        switch templateId {
        case "us-federal-general-industry-v1": return .general
        case "us-federal-construction-v1":     return .construction
        default:                               return nil
        }
    }

    /// US Federal 템플릿으로 만든 점검 기록에만 참 — KR·미설정·레거시 `checklist_global.json`
    /// 기록은 거짓(§E: "점검 기록은 신규 미국 템플릿의 정확한 versioned templateId로 판별").
    public static func showsFederalNotice(forTemplateId templateId: String) -> Bool {
        usFederalScope(forTemplateId: templateId) != nil
    }
}
