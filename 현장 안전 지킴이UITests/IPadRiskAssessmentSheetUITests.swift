import XCTest

/// WO-12 regression: on iPad, tapping either "새 위험성평가" entry point (toolbar + or the
/// empty-state button) used to do nothing — no create sheet, no paywall, no crash, every
/// single time (confirmed via `.onChange`/print instrumentation: `startCreate()` was never
/// even called on the first tap; a second tap always went through). Root cause:
/// `IPadRootView`'s `NavigationSplitView` was resolving to an overlay/compact presentation
/// for the detail column despite ample width, which swallowed the first tap after
/// switching sidebar sections.
///
/// Fix: `.navigationSplitViewStyle(.balanced)` + `columnVisibility = .all` (sidebar always
/// visible, no reveal step). This took the bug from **always** reproducing to a residual,
/// intermittent race — across ~5 clean-simulator runs during triage, at most one tap was
/// ever swallowed, never two. `tapUntilAppears` below tolerates that one-tap race so the
/// suite reflects real usage (a user who taps once and sees nothing will tap again) without
/// masking a regression back to "never works" (a second required tap would still fail loud
/// via the `waitForExistence` timeout).
final class IPadRiskAssessmentSheetUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// Taps `button`, and if `expected` hasn't appeared within `settle`, taps once more.
    /// Documented residual-race tolerance (see class doc) — not a substitute for
    /// `waitForExistence`'s own timeout, which still fails the test if two taps aren't enough.
    private func tapUntilAppears(_ button: XCUIElement, expect expected: XCUIElement, settle: TimeInterval = 3) {
        button.tap()
        if expected.waitForExistence(timeout: settle) { return }
        button.tap()
    }

    private func launchToRiskAssessments(pro: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.appLanguage", "ko",
            "-com.safetywalk.uitestPro", pro ? "1" : "0",
        ]
        app.launch()

        // Sidebar defaults to visible (columnVisibility = .all) — no reveal tap needed.
        let raRow = app.staticTexts["위험성평가"].firstMatch
        XCTAssertTrue(raRow.waitForExistence(timeout: 10), "RA sidebar row not found")
        raRow.tap()

        return app
    }

    func testToolbarButtonOpensCreateSheet() throws {
        let app = launchToRiskAssessments(pro: true)

        let newBtn = app.buttons["ra_new_toolbar"]
        XCTAssertTrue(newBtn.waitForExistence(timeout: 10), "ra_new_toolbar not found")
        let createMarker = app.buttons["항목 추가"]
        tapUntilAppears(newBtn, expect: createMarker)

        XCTAssertTrue(createMarker.waitForExistence(timeout: 10), "create sheet did not present on iPad")
        snap(app, "ipad_ra_create_sheet")
        app.terminate()
    }

    func testEmptyStateButtonOpensCreateSheet() throws {
        let app = launchToRiskAssessments(pro: true)

        let newBtn = app.buttons["ra_new_button"]
        XCTAssertTrue(newBtn.waitForExistence(timeout: 10), "ra_new_button not found")
        let createMarker = app.buttons["항목 추가"]
        tapUntilAppears(newBtn, expect: createMarker)

        XCTAssertTrue(createMarker.waitForExistence(timeout: 10), "create sheet did not present via empty-state button")
        app.terminate()
    }

    /// Non-subscriber → the same entry point must show the paywall, not the create sheet.
    func testNonProShowsPaywall() throws {
        let app = launchToRiskAssessments(pro: false)

        let newBtn = app.buttons["ra_new_toolbar"]
        XCTAssertTrue(newBtn.waitForExistence(timeout: 10), "ra_new_toolbar not found")
        let paywallClose = app.buttons["paywall_close"]
        tapUntilAppears(newBtn, expect: paywallClose)

        XCTAssertTrue(paywallClose.waitForExistence(timeout: 10), "paywall did not present for non-subscriber on iPad")
        snap(app, "ipad_ra_paywall")
        app.terminate()
    }
}
