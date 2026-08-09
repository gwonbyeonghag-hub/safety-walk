import XCTest

/// WO LEGAL-2c runtime QA: drives the 개선조치(corrective action) 1:N flow on the simulator — create
/// an assessment with a 기준 초과 item, confirm its decision, then navigate into the item's 개선조치
/// (depth-2), see the "계획 필요" banner, add a corrective action (depth-3 editor), and confirm the
/// banner clears once the plan exists. Screenshots at each state double as the design-QA artifact.
/// Mirrors RiskAssessmentLegal2bUITests' seed-launch + snap.
final class RiskAssessmentLegal2cUITests: XCTestCase {

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

    func testAddCorrectiveActionToExceedsItem() throws {
        let app = launchApp()

        // Home → RA list → 새 위험성평가
        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "home RA card not shown")
        card.tap()
        let newBtn = app.buttons["새 위험성평가"].firstMatch
        XCTAssertTrue(newBtn.waitForExistence(timeout: 10), "new-assessment button not found")
        newBtn.tap()

        // Pick the seeded site.
        let sitePicker = app.buttons["ra_site_picker"]
        XCTAssertTrue(sitePicker.waitForExistence(timeout: 10), "create site picker not found")
        sitePicker.tap()
        app.buttons["테스트 현장"].firstMatch.tap()
        pickUSJurisdiction(app)   // WO LEGAL-2d-PATH §3: 관할 확인 필수

        // WO LEGAL-2d-PATH: 관할을 확인해야 저장할 수 있다.
        pickUSJurisdiction(app)

        // Add a 빈도×강도 item 2×2 = 4 → exceeds the default threshold 2.
        // WO LEGAL-3A: US 관할을 고르면 업종 섹션이 추가로 렌더돼 "항목 추가" 가 화면 밖으로 밀릴 수 있다.
        let addItem = app.buttons["항목 추가"]
        XCTAssertTrue(scrollToElement(addItem, in: app), "항목 추가 버튼을 찾지 못했다")
        addItem.tap()
        fillItem(app, task: "용접 작업", hazard: "화재·폭발", likelihood: "2", severity: "2")

        // Save → planned 평가가 만들어진다 (즉시 시작 경로는 제거됨).
        let save = app.buttons["저장"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "save button not found")
        save.tap()

        // Open the row → planned 상세에서 시작 → inProgress 에서 결정 확인.
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "assessment row not shown")
        row.tap()
        startAssessmentFromDetail(app)
        let confirm = app.buttons["ra_confirm_decision"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "decision confirm button not shown")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["사업장 설정 기준 초과"].waitForExistence(timeout: 10),
                      "confirmed 기준 초과 decision not shown")
        snap(app, "2c_01_detail_confirmed_plan_required")

        // Navigate into the item's 개선조치 (depth-2) → the 계획 필요 banner must be present.
        let actionsLink = app.buttons["ra_item_actions_link"].firstMatch
        XCTAssertTrue(actionsLink.waitForExistence(timeout: 10), "corrective-action link not shown")
        actionsLink.tap()
        XCTAssertTrue(app.staticTexts["ra_action_plan_required"].waitForExistence(timeout: 10)
                        || app.descendants(matching: .any)["ra_action_plan_required"].waitForExistence(timeout: 2),
                      "plan-required banner not shown for an exceeds item with no plan")
        snap(app, "2c_02_action_list_plan_required")

        // Add a corrective action (depth-3 editor).
        let add = app.buttons["ra_action_add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "add-action button not shown")
        add.tap()
        let measure = app.textFields["ra_action_measure"]
        XCTAssertTrue(measure.waitForExistence(timeout: 10), "measure field not shown")
        measure.tap(); measure.typeText("난간 설치")
        snap(app, "2c_03_action_editor")
        app.buttons["ra_action_save"].tap()

        // Back in the list: the action appears and the 계획 필요 banner is gone (plan satisfied).
        XCTAssertTrue(app.staticTexts["난간 설치"].waitForExistence(timeout: 10),
                      "added corrective action not shown in the list")
        XCTAssertFalse(app.descendants(matching: .any)["ra_action_plan_required"].exists,
                       "plan-required banner should clear once a corrective action exists")
        snap(app, "2c_04_action_list_with_plan")
    }
}
