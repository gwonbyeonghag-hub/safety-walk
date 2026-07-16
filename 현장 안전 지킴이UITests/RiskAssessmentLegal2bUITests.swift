import XCTest

/// WO LEGAL-2b runtime QA: drives the 허용 기준(acceptability criteria) + 기준 이내/초과 decision
/// flow on the simulator and captures a screenshot at each state — criteria selection, the
/// locked criteria after start, the 기준 초과 suggestion, the user's explicit confirmation, and
/// the planned-path criteria-change start. Mirrors RiskAssessment2aUITests' seed-launch + snap.
final class RiskAssessmentLegal2bUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-com.safetywalk.appearanceMode", "light",
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.uitestPro", "1",       // Pro so authoring opens
            "-com.safetywalk.uitestSeedSite", "1",  // SCHEMA_V3 §4.1: a site is required
        ]
        app.launch()
        return app
    }

    /// Immediate "assess now": create with a 빈도×강도 item scoring 4 (2×2) — above the default
    /// threshold 2 — then confirm the 기준 초과 decision in detail. Verifies the criteria lock,
    /// the exceeds suggestion, and that confirmation records the decision.
    func testCreateThenConfirmExceedsDecision() throws {
        let app = launchApp()

        // Home → RA list → 새 위험성평가
        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "home RA card not shown")
        card.tap()
        let newBtn = app.buttons["새 위험성평가"].firstMatch
        XCTAssertTrue(newBtn.waitForExistence(timeout: 10), "new-assessment button not found")
        newBtn.tap()

        // Pick the seeded site so the assessment can save.
        let sitePicker = app.buttons["ra_site_picker"]
        XCTAssertTrue(sitePicker.waitForExistence(timeout: 10), "create site picker not found")
        sitePicker.tap()
        app.buttons["테스트 현장"].firstMatch.tap()
        snap(app, "2b_01_create_criteria")   // criteria section shows the default 1~2 within

        // Add a 빈도×강도 item: likelihood 2 × severity 2 = 4 → exceeds the default threshold 2.
        app.buttons["항목 추가"].tap()
        let task = app.textFields["공정·작업"]
        XCTAssertTrue(task.waitForExistence(timeout: 10), "task field not found")
        task.tap(); task.typeText("용접 작업")
        app.segmentedControls["ra_likelihood"].buttons["2"].firstMatch.tap()
        app.segmentedControls["ra_severity"].buttons["2"].firstMatch.tap()
        app.buttons["완료"].tap()

        // Save → the shared atomic start locks the criteria and flips to inProgress.
        let save = app.buttons["저장"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "save button not found")
        XCTAssertTrue(save.isEnabled, "save should be enabled for an assessed item + site")
        save.tap()

        // Open the new row → inProgress detail.
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "assessment row not shown")
        row.tap()

        // Locked criteria read-only section + the 기준 초과 suggestion with an explicit 확인.
        XCTAssertTrue(app.staticTexts["잠긴 기준"].waitForExistence(timeout: 10),
                      "locked criteria section not shown after start")
        let confirm = app.buttons["ra_confirm_decision"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "decision confirm button not shown")
        snap(app, "2b_02_detail_suggestion")

        // Confirm → the recorded 기준 초과 decision appears and the confirm button is gone.
        confirm.tap()
        XCTAssertTrue(app.staticTexts["사업장 설정 기준 초과"].waitForExistence(timeout: 10),
                      "confirmed 기준 초과 decision not shown")
        XCTAssertFalse(app.buttons["ra_confirm_decision"].exists,
                       "confirm button should disappear once the decision is recorded")
        snap(app, "2b_03_detail_confirmed")
    }

    /// Planned path: start opens the criteria-confirmation sheet; change the range, then start.
    /// Verifies the criteria selection screen and that the locked criteria appears after start.
    func testPlannedStartWithChangedCriteria() throws {
        let app = launchApp()

        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "home RA card not shown")
        card.tap()
        let planButton = app.buttons["ra_plan_toolbar"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "plan toolbar button not shown")
        planButton.tap()
        let sitePicker = app.buttons["plan_site_picker"]
        XCTAssertTrue(sitePicker.waitForExistence(timeout: 10), "plan site picker not found")
        sitePicker.tap()
        app.buttons["테스트 현장"].firstMatch.tap()
        app.buttons["plan_save"].tap()

        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "planned row not shown")
        row.tap()

        // Start → criteria sheet; switch to the "1~4 within" option, then confirm.
        let start = app.buttons["ra_start_assessment"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "start button not shown")
        start.tap()
        // The sheet's confirm button proves the criteria sheet is up.
        let confirmStart = app.buttons["ra_criteria_start_confirm"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 10), "criteria selection sheet not shown")
        // Inline-picker options are Buttons labelled by the option text (not staticTexts).
        let option4 = app.buttons["1~4점 기준 이내 (6점부터 초과)"].firstMatch
        if option4.waitForExistence(timeout: 5) { option4.tap() }
        snap(app, "2b_04_start_sheet_changed")
        confirmStart.tap()

        // Detail is now inProgress with the locked criteria shown read-only.
        XCTAssertTrue(app.staticTexts["잠긴 기준"].waitForExistence(timeout: 10),
                      "locked criteria not shown after start")
        snap(app, "2b_05_detail_locked_criteria")
    }
}
