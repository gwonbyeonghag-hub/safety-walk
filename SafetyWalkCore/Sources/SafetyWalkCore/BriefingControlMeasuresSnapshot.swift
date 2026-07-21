import Foundation

/// Fail-closed errors raised while decoding a `BriefingRiskItemSnapshot.controlMeasuresSnapshot`
/// blob (SCHEMA_V3 §4 "디코딩 실패 fail-closed", 같은 계약을 쓰는 `CriteriaError` 참고). A
/// malformed blob must THROW — it is never silently replaced with an empty list.
public enum BriefingSnapshotError: Error, Equatable {
    case unsupportedFormatVersion(Int)
    case corruptedData
}

/// One 개선조치's value copy at briefing-conduct time — SCHEMA_V3 §4 명시 필드만
/// (measure·담당·기한·status·postRiskLevel). 효과확인·증거사진은 스코프 밖(브리핑 시점엔
/// 아직 없을 수도 있는 평가 쪽 사후 데이터라 여기서 스냅샷하지 않는다).
public struct BriefingControlMeasureSnapshot: Codable, Equatable, Sendable {
    public let actionId: UUID
    public let measure: String?
    public let responsibleName: String?
    public let dueDate: Date?
    public let status: String            // CorrectiveActionStatus raw
    public let postRiskLevel: String?    // RiskLevel raw — nil = 미기록

    /// `dueDate` 는 스냅샷 정밀도(초 단위)로 정규화된다 — `SharingSnapshot` 이 이미 고친 것과 같은
    /// 문제(`.iso8601` 인코딩은 소수초를 버리지만 디코딩은 받아들여, 정규화 없이는
    /// `decode(encode(x)) != x` 가 된다)를 여기서도 막는다.
    public init(actionId: UUID, measure: String?, responsibleName: String?, dueDate: Date?,
                status: String, postRiskLevel: String?) {
        self.actionId = actionId
        self.measure = measure
        self.responsibleName = responsibleName
        self.dueDate = dueDate?.sw_snapshotPrecision
        self.status = status
        self.postRiskLevel = postRiskLevel
    }

    /// Decoding routes through the normalizing initializer too (`SharingSnapshot.Action` 과 같은 이유).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(actionId: try c.decode(UUID.self, forKey: .actionId),
                  measure: try c.decodeIfPresent(String.self, forKey: .measure),
                  responsibleName: try c.decodeIfPresent(String.self, forKey: .responsibleName),
                  dueDate: try c.decodeIfPresent(Date.self, forKey: .dueDate),
                  status: try c.decode(String.self, forKey: .status),
                  postRiskLevel: try c.decodeIfPresent(String.self, forKey: .postRiskLevel))
    }
}

/// The versioned value snapshot stored in `BriefingRiskItemSnapshot.controlMeasuresSnapshot`
/// (SCHEMA_V3 §4 — 1:N 조치 버전형 스냅샷). Pure `Foundation`; deriving one from live
/// `CorrectiveAction` models is `BriefingLifecycle.conduct`'s job, not this type's.
public struct BriefingControlMeasuresSnapshot: Equatable {

    /// Bump ONLY together with a decoder that still reads every older version.
    public static let currentFormatVersion = 1

    public var measures: [BriefingControlMeasureSnapshot]

    public init(measures: [BriefingControlMeasureSnapshot]) {
        self.measures = measures
    }

    // MARK: - Format v1 wire

    private struct Wire: Codable {
        var formatVersion: Int
        var measures: [BriefingControlMeasureSnapshot]
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Encodes to the format-v1 JSON blob. Always produces well-formed bytes — even a 0-action
    /// item (기준 이내라 조치 불필요) encodes to a valid empty-array payload, never raw `Data()`.
    public func encoded() throws -> Data {
        try Self.makeEncoder().encode(Wire(formatVersion: Self.currentFormatVersion, measures: measures))
    }

    /// Decodes + validates a stored blob. FAIL-CLOSED: a version this reader doesn't know, or a
    /// corrupted payload, throws rather than silently returning an empty list. The model's
    /// CloudKit-required stored default (`Data()`) is the only case this treats as truly empty —
    /// it can only reach a reader if a snapshot was persisted without ever going through
    /// `BriefingLifecycle.conduct`.
    public static func decode(_ data: Data, formatVersion: Int) throws -> BriefingControlMeasuresSnapshot {
        guard formatVersion == currentFormatVersion else {
            throw BriefingSnapshotError.unsupportedFormatVersion(formatVersion)
        }
        guard !data.isEmpty else { return BriefingControlMeasuresSnapshot(measures: []) }
        let wire: Wire
        do {
            wire = try makeDecoder().decode(Wire.self, from: data)
        } catch {
            throw BriefingSnapshotError.corruptedData
        }
        guard wire.formatVersion == currentFormatVersion else {
            throw BriefingSnapshotError.unsupportedFormatVersion(wire.formatVersion)
        }
        return BriefingControlMeasuresSnapshot(measures: wire.measures)
    }
}
