import XCTest

/// Drives the Risk Assessment feature end-to-end on the simulator for both
/// methods, attaching screenshots at each key screen. A passing run is itself
/// runtime verification that create → item input → save → list → detail works.
/// Risk inputs are chosen BEFORE typing text so no keyboard dismissal is needed.
final class RiskAssessmentUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.uitestPro", "1",   // WO-10: Pro so the create gate opens
        ]
        app.launch()
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func openCreate(_ app: XCUIApplication) {
        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Home risk-assessment card not found")
        card.tap()
        let newBtn = app.buttons["새 위험성평가"].firstMatch
        XCTAssertTrue(newBtn.waitForExistence(timeout: 10), "New-assessment button not found")
        newBtn.tap()
        XCTAssertTrue(app.buttons["항목 추가"].waitForExistence(timeout: 10), "Add-item button not found")
    }

    func testFrequencySeverityEndToEnd() throws {
        let app = launchApp()
        openCreate(app)
        snap(app, "01_create_freqSeverity_empty")

        app.buttons["항목 추가"].tap()
        // Pick risk first (no keyboard), then the live score + band shows.
        let lk = app.segmentedControls["ra_likelihood"]
        XCTAssertTrue(lk.waitForExistence(timeout: 10), "likelihood control not found")
        lk.buttons["2"].tap()
        app.segmentedControls["ra_severity"].buttons["3"].tap()   // score 6 → 높음
        snap(app, "02_editor_freqSeverity_score")

        let task = app.textFields["공정·작업"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        task.typeText("용접 작업")
        app.buttons["완료"].tap()

        snap(app, "03_create_with_item")
        app.buttons["저장"].tap()

        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "saved assessment row not found")
        snap(app, "04_list_one")
        row.tap()
        XCTAssertTrue(app.staticTexts["용접 작업"].waitForExistence(timeout: 10), "item not in detail")
        snap(app, "05_detail")
    }

    func testThreeLevelEditor() throws {
        let app = launchApp()
        openCreate(app)
        app.buttons["ra_method_picker"].tap()                       // open method menu (4 methods)
        app.buttons["3단계"].firstMatch.tap()                       // switch method
        app.buttons["항목 추가"].tap()

        let medium = app.buttons["보통"].firstMatch
        XCTAssertTrue(medium.waitForExistence(timeout: 10), "3-level medium button not found")
        medium.tap()
        snap(app, "06_editor_threeLevel")

        let task = app.textFields["공정·작업"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        task.typeText("고소 작업")
        app.buttons["완료"].tap()
        snap(app, "07_create_threeLevel")
    }
}
