import XCTest

/// LEGAL-0 UI evidence: captures the three risk-input-safety states on the
/// simulator — ① 미입력 "미평가" 표시, ② 미완성 저장 차단, ③ 저장실패 알럿 + 화면 유지.
/// The states are the real behaviour; screenshot #3 uses a DEBUG-only launch flag
/// to enable the 저장 button so the genuine guard-throw alert can be photographed.
final class RiskAssessmentLegal0UITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launchApp(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.uitestPro", "1",   // WO-10: Pro so the create gate opens
        ] + extra
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

    /// Adds one 빈도×강도 item WITHOUT choosing likelihood/severity — it stays 미평가.
    private func addUnassessedItem(_ app: XCUIApplication) {
        app.buttons["항목 추가"].tap()
        let task = app.textFields["공정·작업"]
        XCTAssertTrue(task.waitForExistence(timeout: 10), "task field not found")
        task.tap()
        task.typeText("용접 작업")   // title only; risk deliberately left unset
    }

    // ① 미평가 표시 + ② 미완성 저장 차단 (no DEBUG flag → 저장 stays disabled).
    func testUnassessedShownAndSaveBlocked() throws {
        let app = launchApp()
        openCreate(app)
        addUnassessedItem(app)
        // Editor with no score chosen shows the "—" placeholder (미입력 at input time).
        snap(app, "legal0_01_editor_unassessed")
        app.buttons["완료"].tap()

        // Back on the create screen: row shows the neutral 미평가 chip + the reason hint.
        let unassessed = app.staticTexts["미평가"].firstMatch
        XCTAssertTrue(unassessed.waitForExistence(timeout: 10), "미평가 chip not shown")
        XCTAssertTrue(app.staticTexts["ra_incomplete_hint"].exists
                      || app.otherElements["ra_incomplete_hint"].exists
                      || app.staticTexts["위험도가 미입력된 항목이 있어 저장할 수 없습니다"].exists,
                      "incomplete-save hint not shown")
        // ② 저장 must be disabled while an item is 미평가.
        XCTAssertFalse(app.buttons["저장"].isEnabled, "저장 should be disabled for a 미평가 item")
        snap(app, "legal0_02_row_unassessed_save_blocked")
    }

    // ③ 저장실패 알럿 + 화면 유지 — DEBUG flag enables 저장 so the real guard-throw alert shows.
    func testSaveFailureAlertKeepsScreen() throws {
        let app = launchApp(extra: ["-com.safetywalk.uitestAllowIncompleteSave", "1"])
        openCreate(app)
        addUnassessedItem(app)
        app.buttons["완료"].tap()

        let save = app.buttons["저장"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        XCTAssertTrue(save.isEnabled, "DEBUG flag should enable 저장 for this test")
        save.tap()

        // The real save() throws → alert, and the screen is NOT dismissed.
        XCTAssertTrue(app.staticTexts["저장 실패"].waitForExistence(timeout: 10),
                      "save-failure alert not shown")
        snap(app, "legal0_03_save_failed_alert")

        app.buttons["확인"].tap()   // dismiss alert
        XCTAssertTrue(app.buttons["항목 추가"].waitForExistence(timeout: 10),
                      "should remain on the create screen after a failed save")
    }
}
