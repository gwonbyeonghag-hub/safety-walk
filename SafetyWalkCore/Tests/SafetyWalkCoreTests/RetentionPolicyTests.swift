import Testing
import Foundation
@testable import SafetyWalkCore

// WO LEGAL-2e §1 — 3년 보존(시행규칙 제37조의4) retainUntil 계산. 앱 가드일 뿐 자동 법 판정이
// 아니므로, 이 스위트는 "판정"을 만들지 않는다는 것도 함께 확인한다(경고 여부만 파생).

@Suite("RetentionPolicy — 3년 보존 기한 (LEGAL-2e)")
struct RetentionPolicyTests {

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func makeAssessment(assessedAt: Date?, createdAt: Date) -> RiskAssessment {
        let ra = RiskAssessment(kind: .regular, method: .frequencySeverity,
                                siteId: UUID(), siteName: "1공장", assessorName: "홍길동")
        ra.assessedAt = assessedAt
        ra.createdAt = createdAt
        return ra
    }

    @Test("실시일이 있으면 실시일 + 3년")
    func retainUntilUsesAssessedAt() throws {
        let assessedAt = utc.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let ra = makeAssessment(assessedAt: assessedAt, createdAt: assessedAt.addingTimeInterval(-86400))
        let until = try #require(RetentionPolicy.retainUntil(ra, calendar: utc))
        #expect(utc.dateComponents([.year, .month, .day], from: until) ==
                DateComponents(year: 2029, month: 3, day: 10))
    }

    @Test("실시 전(계획 단계)이면 생성일 + 3년으로 대체 — 리포트 실시일 폴백과 동일")
    func retainUntilFallsBackToCreatedAt() throws {
        let createdAt = utc.date(from: DateComponents(year: 2026, month: 7, day: 21))!
        let ra = makeAssessment(assessedAt: nil, createdAt: createdAt)
        let until = try #require(RetentionPolicy.retainUntil(ra, calendar: utc))
        #expect(utc.dateComponents([.year, .month, .day], from: until) ==
                DateComponents(year: 2029, month: 7, day: 21))
    }

    @Test("보존 기한 이전은 보존 기간 내")
    func withinRetentionBeforeDeadline() throws {
        let assessedAt = utc.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let ra = makeAssessment(assessedAt: assessedAt, createdAt: assessedAt)
        let justBefore = utc.date(from: DateComponents(year: 2028, month: 12, day: 31))!
        #expect(RetentionPolicy.isWithinRetentionPeriod(ra, now: justBefore, calendar: utc))
    }

    @Test("보존 기한 당일부터는 보존 기간이 지남 — 경고 없음")
    func retentionElapsedOnDeadline() throws {
        let assessedAt = utc.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let ra = makeAssessment(assessedAt: assessedAt, createdAt: assessedAt)
        let deadline = try #require(RetentionPolicy.retainUntil(ra, calendar: utc))
        #expect(!RetentionPolicy.isWithinRetentionPeriod(ra, now: deadline, calendar: utc))
    }
}
