import Testing
import Foundation
import SafetyWalkCore
@testable import 현장_안전_지킴이

// WO LEGAL-3A R1: `RiskAssessment.industryDisplayText` is the single shared display value for
// the stored 업종 스냅샷 — nil = 미기록 (the shared `raNotRecorded` label), never a bespoke
// per-screen fallback. iOS 상세·macOS 조회·KR/US PDF 네 곳이 전부 이 값만 읽는다.

@MainActor
@Suite("RiskAssessment.industryDisplayText — shared 업종 표시값 (WO LEGAL-3A R1)")
struct IndustryProfileCodeDisplayTests {

    private func assessment(industryProfileSnapshot: IndustryProfileCode?) -> RiskAssessment {
        RiskAssessment(kind: .regular, method: .frequencySeverity,
                       siteId: UUID(), siteName: "1공장", assessorName: "홍길동",
                       industryProfileSnapshot: industryProfileSnapshot)
    }

    @Test func nilSnapshotShowsSharedNotRecordedLabel() {
        let ra = assessment(industryProfileSnapshot: nil)
        #expect(ra.industryDisplayText == LocalizationKey.raNotRecorded.localized)
    }

    @Test func setSnapshotShowsItsIndustryLabel() {
        #expect(assessment(industryProfileSnapshot: .general).industryDisplayText
                == LocalizationKey.raIndustryGeneral.localized)
        #expect(assessment(industryProfileSnapshot: .construction).industryDisplayText
                == LocalizationKey.raIndustryConstruction.localized)
        #expect(assessment(industryProfileSnapshot: .electric).industryDisplayText
                == LocalizationKey.raIndustryElectric.localized)
    }
}
