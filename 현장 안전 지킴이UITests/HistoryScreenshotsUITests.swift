import XCTest

/// WO-13 verification screenshots (iPhone): the grouped History tab in both date and site
/// modes, plus the onboarding screen showing the "SafetyWalk" title with the Korean brand
/// line beneath it. History content comes from the DEBUG launch-arg seed
/// (`-com.safetywalk.uitestSeedHistory`), which pins a fixed reference date so every date
/// bucket (오늘/어제/이번 주/이번 달/그이전) renders deterministically.
final class HistoryScreenshotsUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func launch(seed: Bool, onboarded: Bool, mode: String, lang: String = "ko") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.safetywalk.appLanguage", lang,
            "-com.safetywalk.appearanceMode", mode,
        ]
        if onboarded {
            app.launchArguments += [
                "-com.safetywalk.hasCompletedOnboarding", "1",
                "-com.safetywalk.inspectorName", "김안전",
            ]
        }
        if seed {
            app.launchArguments += ["-com.safetywalk.uitestSeedHistory", "1"]
        }
        app.launch()
        return app
    }

    private func captureHistory(mode: String) {
        let app = launch(seed: true, onboarded: true, mode: mode)

        let historyTab = app.tabBars.buttons["기록"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 20), "History tab not found")
        historyTab.tap()

        // Date mode is the default. Confirm a seeded bucket header rendered, then capture.
        XCTAssertTrue(app.staticTexts["오늘"].waitForExistence(timeout: 10), "date-group header not found")
        snap(app, "iphone_history_bydate_\(mode)")

        // Switch to site grouping and capture.
        let siteSegment = app.buttons["현장순"]
        XCTAssertTrue(siteSegment.waitForExistence(timeout: 5), "site-sort segment not found")
        siteSegment.tap()
        XCTAssertTrue(app.staticTexts["가나물류센터 A동"].waitForExistence(timeout: 10), "site-group header not found")
        snap(app, "iphone_history_bysite_\(mode)")

        app.terminate()
    }

    func testHistoryGroupingLight() throws { captureHistory(mode: "light") }
    func testHistoryGroupingDark()  throws { captureHistory(mode: "dark") }

    private func captureOnboarding(mode: String) {
        let app = launch(seed: false, onboarded: false, mode: mode)

        // Title is now "SafetyWalk" with the Korean brand line beneath it (ko-only 병기).
        XCTAssertTrue(app.staticTexts["SafetyWalk"].waitForExistence(timeout: 20), "onboarding title not found")
        XCTAssertTrue(app.staticTexts["현장 안전 지킴이"].waitForExistence(timeout: 5), "ko brand line not found")
        snap(app, "iphone_onboarding_\(mode)")

        app.terminate()
    }

    func testOnboardingBrandLight() throws { captureOnboarding(mode: "light") }
    func testOnboardingBrandDark()  throws { captureOnboarding(mode: "dark") }
}
