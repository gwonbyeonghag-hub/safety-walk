import XCTest

/// WO-13 verification screenshots (iPad): the grouped History tab in date and site modes
/// inside the NavigationSplitView shell. Because the sidebar is always visible
/// (columnVisibility = .all, WO-12), each capture also shows the "SafetyWalk" sidebar
/// header — covering the in-app name change too. History content comes from the DEBUG
/// launch-arg seed (`-com.safetywalk.uitestSeedHistory`).
final class HistoryScreenshotsIPadUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func launch(mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.safetywalk.appLanguage", "ko",
            "-com.safetywalk.appearanceMode", mode,
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "김안전",
            "-com.safetywalk.uitestSeedHistory", "1",
        ]
        app.launch()
        return app
    }

    private func captureHistory(mode: String) {
        let app = launch(mode: mode)

        // Sidebar defaults to visible (WO-12). Select the History section.
        let historyRow = app.staticTexts["기록"].firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 20), "History sidebar row not found")
        historyRow.tap()

        XCTAssertTrue(app.staticTexts["오늘"].waitForExistence(timeout: 10), "date-group header not found")
        snap(app, "ipad_history_bydate_\(mode)") // also shows the SafetyWalk sidebar header

        let siteSegment = app.buttons["현장순"]
        XCTAssertTrue(siteSegment.waitForExistence(timeout: 5), "site-sort segment not found")
        siteSegment.tap()
        XCTAssertTrue(app.staticTexts["가나물류센터 A동"].waitForExistence(timeout: 10), "site-group header not found")
        snap(app, "ipad_history_bysite_\(mode)")

        app.terminate()
    }

    func testIPadHistoryGroupingLight() throws { captureHistory(mode: "light") }
    func testIPadHistoryGroupingDark()  throws { captureHistory(mode: "dark") }
}
