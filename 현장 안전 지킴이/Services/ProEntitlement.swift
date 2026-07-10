import Foundation

/// Pure Pro-entitlement policy (WO-10). Deliberately free of StoreKit so the paywall
/// gates are decided by a function that can be exhaustively tested without a live App
/// Store: 비구독 / 활성(월·연) / 만료 / 취소 / 복원 / 타상품 / 경계(== now).
/// `ProStore` maps `Transaction.currentEntitlements` onto `Record`s and calls `isPro`.
enum ProEntitlement {

    /// The "SafetyWalk Pro" subscription group's product identifiers. Prices are **not**
    /// hard-coded — the paywall shows StoreKit's `displayPrice` (owner sets prices in
    /// App Store Connect).
    static let productIDs: Set<String> = [
        "com.gwonbyeonghag.safetywalk.pro.monthly",
        "com.gwonbyeonghag.safetywalk.pro.yearly",
    ]

    /// A StoreKit-independent view of one entitlement transaction.
    struct Record {
        let productID: String
        /// nil = no expiry (non-subscription); auto-renewable subs always set it.
        let expirationDate: Date?
        /// non-nil = refunded / revoked by the store.
        let revocationDate: Date?
    }

    /// Pro is active iff any record is one of our products, is not revoked, and either has
    /// no expiry or expires strictly after `now` (an expiry exactly == now counts as
    /// expired). StoreKit's `currentEntitlements` already excludes expired/revoked, so in
    /// practice a non-empty match means Pro; the extra checks make the policy self-contained.
    static func isPro(records: [Record], now: Date) -> Bool {
        records.contains { record in
            productIDs.contains(record.productID)
                && record.revocationDate == nil
                && (record.expirationDate.map { $0 > now } ?? true)
        }
    }
}
