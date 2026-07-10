import XCTest
@testable import 현장_안전_지킴이

/// WO-10: the Pro entitlement decision is a pure function so the paywall gates can be
/// proven without a live StoreKit — covers 비구독 / 구독(월·연) / 만료 / 취소 / 복원 /
/// 타상품 / 경계(== now). StoreKit's `currentEntitlements` already excludes expired &
/// revoked, but modeling those here keeps the policy explicit and independently tested.
final class ProEntitlementTests: XCTestCase {

    private let monthly = "com.gwonbyeonghag.safetywalk.pro.monthly"
    private let yearly  = "com.gwonbyeonghag.safetywalk.pro.yearly"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func record(_ productID: String,
                        expires: TimeInterval? = 60 * 60 * 24 * 30,
                        revoked: Bool = false) -> ProEntitlement.Record {
        ProEntitlement.Record(
            productID: productID,
            expirationDate: expires.map { now.addingTimeInterval($0) },
            revocationDate: revoked ? now.addingTimeInterval(-1) : nil
        )
    }

    // 1. 비구독 — no entitlements at all.
    func testNonSubscriberIsNotPro() {
        XCTAssertFalse(ProEntitlement.isPro(records: [], now: now))
    }

    // 2/3. 구독 — an unexpired monthly OR yearly grants Pro.
    func testActiveMonthlyIsPro() {
        XCTAssertTrue(ProEntitlement.isPro(records: [record(monthly)], now: now))
    }
    func testActiveYearlyIsPro() {
        XCTAssertTrue(ProEntitlement.isPro(records: [record(yearly)], now: now))
    }

    // 4. 만료 — expiration in the past ⇒ not Pro (view still allowed elsewhere by design).
    func testExpiredIsNotPro() {
        XCTAssertFalse(ProEntitlement.isPro(
            records: [record(monthly, expires: -60)], now: now))
    }

    // 5. 취소(revocation) — refunded/revoked ⇒ not Pro even if not yet expired.
    func testRevokedIsNotPro() {
        XCTAssertFalse(ProEntitlement.isPro(
            records: [record(yearly, revoked: true)], now: now))
    }

    // 6. 복원 — after restore a valid entitlement reappears ⇒ Pro.
    func testRestoredValidEntitlementIsPro() {
        XCTAssertTrue(ProEntitlement.isPro(
            records: [record(monthly, expires: 60 * 60 * 24 * 365)], now: now))
    }

    // 7. 타상품 — some other product must never grant our Pro.
    func testUnknownProductIsNotPro() {
        XCTAssertFalse(ProEntitlement.isPro(
            records: [record("com.someone.else.plus")], now: now))
    }

    // 8. 경계 — expiration exactly == now is treated as expired (strictly future required).
    func testExpirationEqualToNowIsNotPro() {
        XCTAssertFalse(ProEntitlement.isPro(
            records: [record(monthly, expires: 0)], now: now))
    }

    // Mixed bag — one valid entitlement among expired/other ⇒ Pro.
    func testAnyValidEntitlementGrantsPro() {
        let records = [record(monthly, expires: -60), record("x.y.z"), record(yearly)]
        XCTAssertTrue(ProEntitlement.isPro(records: records, now: now))
    }
}
