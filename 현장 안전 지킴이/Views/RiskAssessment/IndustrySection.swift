import SwiftUI
import SafetyWalkCore

/// 미국 업종 범위 선택 — 두 생성 경로(새 평가 · 평가 계획)가 공유하는 하나의 섹션 (WO LEGAL-3A).
///
/// **US 관할에서만 나타나고 필수다** (`JurisdictionPolicy.requiresIndustry`) — 위험 임계값이 업종마다
/// 달라(General Industry vs Construction 등) 범위 없는 US 기록은 어느 기준을 참조했는지 알 수 없다.
/// KR·미설정에는 이 섹션이 나타나지 않는다 — 지역 프로파일이나 표시 언어로 자동 선택되지 않는다.
struct IndustrySection: View {
    @Binding var industryProfile: IndustryProfileCode?

    var body: some View {
        Section(LocalizationKey.raIndustry.localized) {
            Picker(LocalizationKey.raIndustry.localized, selection: $industryProfile) {
                Text(LocalizationKey.raIndustrySelect.localized).tag(IndustryProfileCode?.none)
                ForEach(IndustryProfileCode.allCases) { code in
                    Text(code.localizedLabel).tag(IndustryProfileCode?.some(code))
                }
            }
            .accessibilityIdentifier("ra_industry_picker")

            Text(LocalizationKey.raIndustryHint.localized)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)
        }
    }
}
