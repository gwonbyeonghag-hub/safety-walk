import XCTest
import StoreKitTest

/// WO-10 paywall demo. Products (and their `displayPrice`) come from a real local StoreKit
/// test session — no App Store account. `isPro` is pinned via a DEBUG-only launch argument
/// because the simulator's StoreKit test store cannot be reliably cleared headlessly in
/// this environment (a phantom entitlement survives erase + resetToDefaultState); the
/// entitlement *decision* itself is proven exhaustively by `ProEntitlementTests`.
/// The `-uitest-*` arguments are compiled out of Release (see ProStore.start()).
final class ProPaywallUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func launch(lang: String = "ko", mode: String = "light", pro: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.appLanguage", lang,
            "-com.safetywalk.appearanceMode", mode,
            "-com.safetywalk.uitestPro", pro ? "1" : "0",
        ]
        app.launch()
        return app
    }

    /// Home → RA list → tap "new assessment" (language-independent identifier).
    /// Uses the toolbar + (`ra_new_toolbar`), which exists whether or not the list has
    /// data — `ra_new_button` only renders in the empty state, so asserting on it made
    /// the suite fail on any simulator with leftover assessments (planner review).
    private func tapNewAssessment(_ app: XCUIApplication) {
        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "home RA card not found")
        card.tap()
        let newBtn = app.buttons["ra_new_toolbar"]
        XCTAssertTrue(newBtn.waitForExistence(timeout: 10), "RA new button not found")
        newBtn.tap()
    }

    // 비구독 → 페이월 (with real StoreKit prices), in ko/en × light/dark.
    func testPaywallForNonSubscriber() throws {
        let session = try ProTestSupport.cleanSession()   // real products for the paywall
        addTeardownBlock { session.clearTransactions() }

        for lang in ["ko", "en"] {
            for mode in ["light", "dark"] {
                let app = launch(lang: lang, mode: mode, pro: false)
                tapNewAssessment(app)
                // Gate must show the paywall (isPro pinned false) — assert on the always-present
                // close control so this is independent of async product loading.
                XCTAssertTrue(app.buttons["paywall_close"].waitForExistence(timeout: 15),
                              "gate did not show the paywall (\(lang)/\(mode))")
                snap(app, "paywall_\(lang)_\(mode)")
                app.terminate()
            }
        }
    }

    // Settings shows the Pro status: a non-subscriber sees 미구독 (not 구독 중).
    func testSettingsShowsNotSubscribedForNonSubscriber() throws {
        let app = launch(pro: false)
        XCTAssertTrue(app.buttons["gear"].waitForExistence(timeout: 20), "settings tab not found")
        app.buttons["gear"].tap()
        let notSub = app.staticTexts["미구독"].waitForExistence(timeout: 10)
        let sub = app.staticTexts["구독 중"].exists
        snap(app, "settings_pro_status")
        XCTAssertTrue(notSub && !sub, "pro=false should show 미구독 (subscribed=\(sub))")
    }

    // Pro → the new-creation gate opens the create sheet instead of the paywall.
    func testProUnlocksCreateGate() throws {
        let app = launch(pro: true)
        tapNewAssessment(app)
        XCTAssertTrue(app.buttons["항목 추가"].waitForExistence(timeout: 15),
                      "Pro should open the create sheet, not the paywall")
        snap(app, "unlocked_create")
        app.terminate()
    }
}
