import Foundation

/// Why a stored `contentSnapshot` could not be read back (WO LEGAL-2d §3). Decoding is
/// **fail-closed**: a caller that cannot decode must show an error state, never fall back to the
/// assessment's CURRENT data — that would silently present today's content as "what was shared".
public enum SharingSnapshotError: Error, Equatable {
    case unsupportedFormatVersion   // 미래(또는 미지) 포맷 — 조용히 읽지 않는다
    case malformed                  // JSON 아님 / 필수 키 누락 / 인코딩 불가
}

/// The versioned value snapshot stored in `SharingEvent.contentSnapshot` (WO LEGAL-2d §3).
///
/// A `SharingEvent` proves *what was shared at the time*, so it can never reference live models —
/// every user-entered value is COPIED and every enum is stored as its stable `rawValue`. Editing or
/// deleting the source assessment afterwards leaves this JSON untouched.
///
/// Deliberately excluded: 증거사진 binary and 참여자 개인정보. Both already live on their owning
/// records; duplicating them here would spread personal data across immutable copies for no
/// legal benefit (LEGAL_SOURCE_TABLE A.2 lists 유해위험요인·결정·개선대책·이행결과 as the 공유 범위).
///
/// This type is pure `Foundation` — deriving one from the SwiftData models is
/// `SharingEventPolicy.makeSnapshot(phase:for:)`.
public struct SharingSnapshot: Codable, Equatable, Sendable {

    /// Bump ONLY together with a decoder that still reads every older version. Readers reject a
    /// version they don't know rather than guessing (`unsupportedFormatVersion`).
    public static let currentFormatVersion = 1

    public let formatVersion: Int
    public let phase: String              // SharingPhase raw code
    public let assessmentId: UUID
    public let siteName: String
    public let kind: String               // RiskAssessmentKind raw code
    public let method: String             // RiskAssessmentMethod raw code
    public let jurisdiction: String?      // JurisdictionCode raw code — nil = 관할 미설정
    public let industryProfile: String?   // IndustryProfileCode raw code — nil = 미설정
    /// 사전 공유의 핵심 값 — 이 일정이 현재 일정과 다르면 그 사전 공유는 stale 이다.
    public let scheduledAt: Date?
    /// 사후 공유에만 채워진다 (사전 = 일정 공유이므로 빈 배열).
    public let items: [Item]

    /// 한 항목의 당시 유해위험요인·위험성 결정 + 그 항목이 소유한 1:N 개선조치 전부.
    public struct Item: Codable, Equatable, Sendable {
        public let itemId: UUID
        public let sortOrder: Int
        public let taskDescription: String
        public let hazardDescription: String
        public let currentControls: String?
        public let riskLevel: String?           // RiskLevel raw — nil = 미평가
        public let likelihood: Int?
        public let severity: Int?
        public let criteriaDecision: String?    // CriteriaDecision raw — nil = 미확정
        public let decisionConfirmedAt: Date?
        public let decisionConfirmedBy: String?
        public let correctiveActions: [Action]
    }

    /// 한 개선조치의 담당·기한·상태·이행일·개선후위험도·효과확인 결과 (증거사진 제외).
    public struct Action: Codable, Equatable, Sendable {
        public let actionId: UUID
        public let measure: String?
        public let responsibleName: String?
        public let dueDate: Date?
        public let status: String               // CorrectiveActionStatus raw
        public let implementedAt: Date?
        public let postRiskLevel: String?       // RiskLevel raw
        public let effectivenessResult: String? // EffectivenessResult raw — nil = 미확인
        public let effectivenessConfirmedAt: Date?
        public let confirmedBy: String?
    }

    // MARK: - Codec

    /// Deterministic by construction: sorted keys + a fixed UTC ISO-8601 date form, so the same
    /// domain state always produces byte-identical JSON. Staleness detection (`SharingEventPolicy`)
    /// relies on that — it re-derives the current snapshot and compares.
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601   // UTC, locale/timezone independent
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public func encoded() throws -> String {
        guard let json = String(data: try Self.makeEncoder().encode(self), encoding: .utf8) else {
            throw SharingSnapshotError.malformed
        }
        return json
    }

    /// Reads a stored snapshot back. Throws (never returns a partial/substituted value) when the
    /// payload is not this format — the caller must surface a fail-closed error state.
    public static func decode(_ json: String) throws -> SharingSnapshot {
        guard let data = json.data(using: .utf8) else { throw SharingSnapshotError.malformed }
        // Probe the version FIRST so a future payload reports the precise reason instead of
        // failing as generic malformed JSON once its shape diverges.
        guard let probe = try? makeDecoder().decode(VersionProbe.self, from: data) else {
            throw SharingSnapshotError.malformed
        }
        guard probe.formatVersion == currentFormatVersion else {
            throw SharingSnapshotError.unsupportedFormatVersion
        }
        guard let snapshot = try? makeDecoder().decode(SharingSnapshot.self, from: data) else {
            throw SharingSnapshotError.malformed
        }
        return snapshot
    }

    private struct VersionProbe: Decodable { let formatVersion: Int }
}
