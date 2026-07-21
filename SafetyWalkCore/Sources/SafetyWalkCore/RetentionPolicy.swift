import Foundation

/// 3년 보존 안내 (SCHEMA_V3 §5 "3년 보존=앱 가드" · 시행규칙 제37조의4) — WO LEGAL-2e.
///
/// 보존은 **앱의 안내일 뿐 자동 법 판정이 아니다** — `retainUntil` 이전이라도 사용자가 확인하면
/// 삭제를 막지 않는다(CLAUDE.md No legal judgment). 화면이 이 값을 읽어 삭제 확인에 경고를
/// 얹을 뿐, 이 타입은 어떤 삭제도 거부하지 않는다(`AssessmentDeletion` 참고).
public enum RetentionPolicy {

    /// 시행규칙 제37조의4 보존 기간.
    public static let retentionPeriodYears = 3

    /// 기록의 실시 시기 — `RiskAssessmentReport`(WO-5b)가 이미 "실시일" 표시에 쓰는 것과 같은
    /// 폴백(실시 전이면 생성일)을 재사용한다. 단일 소스.
    private static func recordDate(_ assessment: RiskAssessment) -> Date {
        assessment.assessedAt ?? assessment.createdAt
    }

    /// 보존 기한 = 실시 시기 + 3년.
    public static func retainUntil(_ assessment: RiskAssessment,
                                   calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .year, value: retentionPeriodYears, to: recordDate(assessment))
    }

    /// `now` 가 아직 보존 기한 이전인가 — 삭제 확인에 경고를 얹을지 정하는 단일 규칙. 날짜 연산이
    /// 실패하면(사실상 발생하지 않음) fail-closed: 경고를 생략하지 않는다.
    public static func isWithinRetentionPeriod(_ assessment: RiskAssessment, now: Date,
                                               calendar: Calendar = .current) -> Bool {
        guard let until = retainUntil(assessment, calendar: calendar) else { return true }
        return now < until
    }
}
