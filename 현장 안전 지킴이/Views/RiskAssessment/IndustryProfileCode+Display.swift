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

extension RiskAssessment {
    /// 저장된 업종 스냅샷의 공유 표시값 — 상세(iOS)·조회(macOS)·KR/US PDF 네 곳이 전부 이 값만
    /// 쓴다(WO LEGAL-3A R1, 네 곳이 각자 `?? raNotRecorded` 를 반복하며 드리프트하는 것을 막는다).
    /// `nil` = 미기록이며 실제 값처럼 계산에 넣지 않는다(CLAUDE.md 기본값≠미기록 원칙).
    var industryDisplayText: String {
        industryProfileSnapshot?.localizedLabel ?? LocalizationKey.raNotRecorded.localized
    }
}
