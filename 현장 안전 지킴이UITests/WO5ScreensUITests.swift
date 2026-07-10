import XCTest

/// WO-5: captures key screens in light + dark for the design-polish before/after.
/// Uses UITest (keeps the app active so the launch intro completes and content renders;
/// plain simctl launch leaves contentOpacity at 0). Appearance forced via the
/// appearanceMode UserDefaults argument domain.
final class WO5ScreensUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func app(mode: String, onboarded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-com.safetywalk.appearanceMode", mode,
            "-com.safetywalk.hasCompletedOnboarding", onboarded ? "1" : "0",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.uitestPro", "1",   // WO-10: Pro so RA create opens
        ]
        app.launch()
        return app
    }

    func testCaptureBothAppearances() throws {
        for mode in ["light", "dark"] {
            // Onboarding — palette (accent on language toggle + start button)
            let onboarding = app(mode: mode, onboarded: false)
            XCTAssertTrue(onboarding.buttons["English"].waitForExistence(timeout: 20),
                          "onboarding not shown (\(mode))")
            snap(onboarding, "after_onboarding_\(mode)")
            onboarding.terminate()

            // Home — navy accent buttons + liquid-glass risk rail
            let home = app(mode: mode, onboarded: true)
            let card = home.buttons["ra_home_card"]
            XCTAssertTrue(card.waitForExistence(timeout: 20), "home not shown (\(mode))")
            snap(home, "after_home_\(mode)")

            // Risk Assessment detail — unified glass RiskChip across low/med/high
            card.tap()
            home.buttons["새 위험성평가"].firstMatch.tap()
            XCTAssertTrue(home.buttons["항목 추가"].waitForExistence(timeout: 10))
            // default method = 빈도×강도; add 3 items spanning low/med/high
            addFreqItem(home, likelihood: "1", severity: "1", task: "낮음 작업")  // 1 → 하
            addFreqItem(home, likelihood: "2", severity: "2", task: "보통 작업")  // 4 → 중
            addFreqItem(home, likelihood: "3", severity: "3", task: "높음 작업")  // 9 → 상
            snap(home, "after_ra_create_\(mode)")
            home.buttons["저장"].tap()
            let row = home.cells.firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.tap()
            XCTAssertTrue(home.staticTexts["높음 작업"].waitForExistence(timeout: 10))
            snap(home, "after_ra_detail_\(mode)")
            home.terminate()
        }
    }

    private func addFreqItem(_ app: XCUIApplication, likelihood: String, severity: String, task: String) {
        app.buttons["항목 추가"].tap()
        let lk = app.segmentedControls["ra_likelihood"]
        XCTAssertTrue(lk.waitForExistence(timeout: 10))
        lk.buttons[likelihood].tap()
        app.segmentedControls["ra_severity"].buttons[severity].tap()
        let field = app.textFields["공정·작업"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(task)
        app.buttons["완료"].tap()
    }
}
