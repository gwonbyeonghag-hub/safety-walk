import SwiftUI
import SafetyWalkCore

/// 법적 관할 선택 — 두 생성 경로(새 평가 · 평가 계획)가 공유하는 하나의 섹션 (WO LEGAL-2d-PATH §3).
///
/// **선택은 비어 있는 상태로 시작한다.** 지역 프로파일(`RegionProfile`)은 추천값을 *보여줄* 뿐이며
/// 절대 자동으로 채우거나 확정하지 않는다 — 관할은 그 평가에 어떤 기록이 필요한지를 정하는 법적 축이라
/// 사용자가 명시적으로 확인해야 한다. `RegionProfile`(콘텐츠 축)·표시 언어와는 **서로 독립**이다.
struct JurisdictionSection: View {
    @Binding var jurisdiction: JurisdictionCode?
    /// 현재 지역 프로파일 — 추천 문구에만 쓰인다.
    let regionProfile: RegionProfile

    private var suggested: JurisdictionCode { JurisdictionPolicy.suggested(for: regionProfile) }

    var body: some View {
        Section(LocalizationKey.raJurisdiction.localized) {
            Picker(LocalizationKey.raJurisdiction.localized, selection: $jurisdiction) {
                Text(LocalizationKey.raJurisdictionSelect.localized).tag(JurisdictionCode?.none)
                ForEach(JurisdictionCode.allCases) { code in
                    Text(code.localizedLabel).tag(JurisdictionCode?.some(code))
                }
            }
            .accessibilityIdentifier("ra_jurisdiction_picker")

            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: LocalizationKey.raJurisdictionSuggestedFmt.localized,
                            suggested.localizedLabel))
                    .font(.caption)
                Text(LocalizationKey.raJurisdictionHint.localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if JurisdictionPolicy.requiresSchedule(jurisdiction) {
                    Text(LocalizationKey.raJurisdictionScheduleHint.localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("ra_jurisdiction_schedule_hint")
                }
            }
            .padding(.vertical, 2)
        }
    }
}

extension JurisdictionCode {
    /// 관할 라벨. 법적 판정 문구가 아니라 **어느 나라의 기록 요건을 따르는지**의 표시다.
    var localizedLabel: String {
        switch self {
        case .kr: return LocalizationKey.raJurisdictionKR.localized
        case .us: return LocalizationKey.raJurisdictionUS.localized
        }
    }
}
