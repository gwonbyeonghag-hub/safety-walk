import Foundation
import StoreKit
import Observation

/// StoreKit 2 entitlement service for SafetyWalk Pro (WO-10). No login / account / server:
/// payment is the Apple ID, verification is on-device via `Transaction.currentEntitlements`,
/// and "restore" is `AppStore.sync()`. The Pro decision itself is the pure, exhaustively
/// tested `ProEntitlement.isPro` — this type only bridges StoreKit to it and exposes the
/// products for the paywall (prices via StoreKit `displayPrice`, never hard-coded).
///
/// Injected at the app root via `.environment` and read by the two gates
/// (RA new-creation, report export) — free features never touch it.
@MainActor
@Observable
final class ProStore {

    /// True while an entitlement grants Pro. Drives the gates; view/read paths ignore it.
    private(set) var isPro = false
    /// The subscription options for the paywall (empty until `start()` loads them).
    private(set) var products: [Product] = []
    private(set) var isPurchasing = false

    var monthly: Product? { products.first { $0.id.hasSuffix(".monthly") } }
    var yearly: Product? { products.first { $0.id.hasSuffix(".yearly") } }

    init() {
        // Catch renewals/revocations that happen while the app is open. Injected once at
        // the app root and lives for the process lifetime, so the listener is never torn
        // down (no `deinit` cancellation needed).
        Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let txn) = update { await txn.finish() }
                await self?.refreshEntitlements()
            }
        }
    }

    /// App-root entry point: load products for display, then resolve current entitlements.
    func start() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        products = (try? await Product.products(for: ProEntitlement.productIDs)) ?? []
    }

    /// Re-resolve Pro from `currentEntitlements` (already excludes expired/revoked; the pure
    /// policy re-checks anyway). This is the single source of `isPro`.
    func refreshEntitlements() async {
        #if DEBUG
        // UI-test only (compiled out of Release, so the App Store build has no entitlement
        // bypass): pin `isPro` via the same UserDefaults argument domain the app uses for its
        // other launch flags, because the simulator's StoreKit test store can't be reliably
        // cleared headlessly. Read fresh here so a stray `Transaction.updates` can't flip it.
        if UserDefaults.standard.object(forKey: "com.safetywalk.uitestPro") != nil {
            isPro = UserDefaults.standard.bool(forKey: "com.safetywalk.uitestPro"); return
        }
        #endif
        var records: [ProEntitlement.Record] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            records.append(ProEntitlement.Record(productID: txn.productID,
                                                 expirationDate: txn.expirationDate,
                                                 revocationDate: txn.revocationDate))
        }
        isPro = ProEntitlement.isPro(records: records, now: Date())
    }

    /// Buy a subscription. Returns whether Pro is active afterwards.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let txn) = verification { await txn.finish() }
                await refreshEntitlements()
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// "구매 복원" — re-sync with the App Store, then re-resolve entitlements.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
