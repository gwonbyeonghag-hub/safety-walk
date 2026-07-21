import Testing
import Foundation
@testable import SafetyWalkCore

// WO LEGAL-TBM-1 §2.3 — BriefingRiskItemSnapshot 이 소유하는 1:N 개선조치 값 스냅샷의 인코딩·
// 디코딩. `CriteriaMatrixSnapshot`/`SharingSnapshot` 과 같은 계약: 손상·미지원 버전은 fail-closed
// 로 던진다(조용히 빈 목록으로 대체하지 않는다).
@Suite("BriefingControlMeasuresSnapshot — 1:N 조치 값 스냅샷 인코딩 (TBM-1)")
struct BriefingControlMeasuresSnapshotTests {

    private let dueDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("빈 조치 목록도 유효하게 인코딩·디코딩된다 (기준 이내 항목)")
    func roundTripsEmptyMeasures() throws {
        let snapshot = BriefingControlMeasuresSnapshot(measures: [])
        let data = try snapshot.encoded()
        let decoded = try BriefingControlMeasuresSnapshot.decode(data, formatVersion: 1)
        #expect(decoded.measures.isEmpty)
    }

    @Test("여러 조치가 순서·값 그대로 왕복한다")
    func roundTripsMultipleMeasures() throws {
        let a1 = BriefingControlMeasureSnapshot(actionId: UUID(), measure: "안전난간 설치",
                                                responsibleName: "김담당", dueDate: dueDate,
                                                status: "notStarted", postRiskLevel: nil)
        let a2 = BriefingControlMeasureSnapshot(actionId: UUID(), measure: "추가 안전교육",
                                                responsibleName: nil, dueDate: nil,
                                                status: "completed", postRiskLevel: "low")
        let snapshot = BriefingControlMeasuresSnapshot(measures: [a1, a2])

        let decoded = try BriefingControlMeasuresSnapshot.decode(try snapshot.encoded(), formatVersion: 1)

        #expect(decoded.measures == [a1, a2])
    }

    @Test("지원하지 않는 formatVersion 은 fail-closed 로 던진다")
    func rejectsUnsupportedFormatVersion() throws {
        let data = try BriefingControlMeasuresSnapshot(measures: []).encoded()
        #expect(throws: BriefingSnapshotError.unsupportedFormatVersion(99)) {
            try BriefingControlMeasuresSnapshot.decode(data, formatVersion: 99)
        }
    }

    @Test("손상된 데이터는 fail-closed 로 던진다 (빈 목록으로 조용히 대체하지 않는다)")
    func rejectsCorruptedData() throws {
        let garbage = Data([0xFF, 0x00, 0x12, 0x34])
        #expect(throws: BriefingSnapshotError.corruptedData) {
            try BriefingControlMeasuresSnapshot.decode(garbage, formatVersion: 1)
        }
    }

    @Test("CloudKit 저장속성 기본값(빈 Data)은 빈 목록으로 읽힌다")
    func emptyDataDecodesToEmptyList() throws {
        let decoded = try BriefingControlMeasuresSnapshot.decode(Data(), formatVersion: 1)
        #expect(decoded.measures.isEmpty)
    }

    /// `SharingSnapshot` 이 이미 고친 것과 같은 버그(반송 1차 P1-A): 소수초를 가진 `Date` 를
    /// `.iso8601` 로 인코딩하면 초 단위로 잘리지만 디코딩은 소수초를 받아들여, 정규화 없이는
    /// `decode(encode(x)) != x` 가 된다. 정규화가 있으면 인코딩 전에 이미 초 단위로 내림되므로
    /// 왕복이 안정적이다.
    @Test("소수초를 가진 dueDate 도 왕복이 안정적이다")
    func fractionalSecondsDueDateRoundTripsStably() throws {
        let fractional = Date(timeIntervalSince1970: 1_700_000_000.789)
        let measure = BriefingControlMeasureSnapshot(actionId: UUID(), measure: "난간 설치",
                                                      responsibleName: "김담당", dueDate: fractional,
                                                      status: "notStarted", postRiskLevel: nil)
        let snapshot = BriefingControlMeasuresSnapshot(measures: [measure])

        let decoded = try BriefingControlMeasuresSnapshot.decode(try snapshot.encoded(), formatVersion: 1)

        #expect(decoded.measures.first?.dueDate == measure.dueDate)
        #expect(decoded.measures.first?.dueDate == fractional.sw_snapshotPrecision)
    }
}
