import SafetyWalkCore

/// 업종 라벨 — iOS 생성 화면(`IndustrySection`)과 macOS 조회 화면(`RiskAssessmentsBrowseView`)이
/// 공유한다(WO LEGAL-3A). Mac 은 이 파일만 필요하므로(생성 UI 는 없음) `IndustrySection.swift` 와
/// 별도 파일로 뒀다 — Xcode 프로젝트의 "Shared (macOS)" 교차 포함 목록에 등록돼 있다.
extension IndustryProfileCode {
    /// 법적 판정 문구가 아니라 참고 프로필 범위 표시다.
    var localizedLabel: String {
        switch self {
        case .general: return LocalizationKey.raIndustryGeneral.localized
        case .construction: return LocalizationKey.raIndustryConstruction.localized
        case .electric: return LocalizationKey.raIndustryElectric.localized
        }
    }
}
