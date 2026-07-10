import Foundation

/// Owner-provided legal URLs shown on the paywall (WO-10). Left empty until the owner
/// hosts them in WO-6 — filling in these two constants is the only change needed; the
/// paywall renders the labels as non-tappable placeholders while they're `nil` (no dead
/// links). Prices are handled by StoreKit `displayPrice`, not here.
enum LegalLinks {
    static let terms: URL? = nil
    static let privacy: URL? = nil
}
