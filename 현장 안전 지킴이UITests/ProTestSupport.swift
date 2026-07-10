import XCTest
import StoreKitTest

/// WO-10 UI-test support. Grants (or withholds) SafetyWalk Pro through a local StoreKit
/// test session — no App Store account, and NO app-side test hook, so production code has
/// no entitlement bypass. The session runs in the test process and controls the separately
/// launched app's StoreKit environment, so there is no in-process double-`finish` conflict
/// (that's why purchase flows live in UI tests, not host-app unit tests).
enum ProTestSupport {
    static let monthlyID = "com.gwonbyeonghag.safetywalk.pro.monthly"
    static let yearlyID  = "com.gwonbyeonghag.safetywalk.pro.yearly"

    /// A clean, dialog-free session with no transactions. Retain it for the test's lifetime.
    static func cleanSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.resetToDefaultState()   // clear any subscription persisted in the sim's test store
        session.clearTransactions()
        return session
    }

    /// Grant Pro before `app.launch()` so gated flows (RA new-creation, report export) are
    /// reachable. The returned session must be kept alive for the whole test.
    static func grantedProSession() async throws -> SKTestSession {
        let session = try cleanSession()
        _ = try await session.buyProduct(identifier: monthlyID)
        return session
    }
}
