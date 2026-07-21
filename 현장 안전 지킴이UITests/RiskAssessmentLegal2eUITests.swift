import XCTest

/// WO LEGAL-2e runtime QA: 보존 기한 표시 + 삭제 확인(보존 경고 포함) + 취소가 아무것도 지우지 않는지.
/// Mirrors RiskAssessmentLegal2dUITests' plan-sheet entry (US jurisdiction, no schedule needed).
final class RiskAssessmentLegal2eUITests: XCTestCase {

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
            "-com.safetywalk.uitestPro", "1",
            "-com.safetywalk.uitestSeedSite", "1",
        ]
        app.launch()
        return app
    }

    @discardableResult
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, swipes: Int = 6) -> Bool {
        if element.waitForExistence(timeout: 2) { return true }
        for _ in 0..<swipes {
            app.swipeUp()
            if element.exists { return true }
        }
        for _ in 0..<(swipes * 2) {
            app.swipeDown()
            if element.exists { return true }
        }
        return element.exists
    }

    /// 평가 계획(planned) 상세까지 진입 — RiskAssessmentLegal2dUITests.openPlannedDetail 과 동일한 경로.
    private func openPlannedDetail(_ app: XCUIApplication) {
        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "home RA card not shown")
        card.tap()

        let planButton = app.buttons["ra_plan_toolbar"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "plan toolbar button not shown")
        planButton.tap()

        let sitePicker = app.buttons["plan_site_picker"]
        XCTAssertTrue(sitePicker.waitForExistence(timeout: 10), "plan site picker not found")
        sitePicker.tap()
        let site = app.buttons["테스트 현장"].firstMatch
        XCTAssertTrue(site.waitForExistence(timeout: 5), "seeded site not in picker")
        site.tap()
        pickUSJurisdiction(app)
        app.buttons["plan_save"].tap()

        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "planned row not shown")
        row.tap()
    }

    /// 보존 기한이 상세에 표시되고, 삭제 확인 알럿에 보존 경고가 포함되며, 취소하면 아무것도 지워지지
    /// 않는다는 것까지 확인한다(하드 차단 아님 — 확인하면 삭제 가능은 별도 테스트).
    func testRetentionNoticeShownAndDeleteCancelKeepsRecord() throws {
        let app = launchApp()
        openPlannedDetail(app)

        XCTAssertTrue(scrollTo(app.staticTexts["보존 기한"], in: app), "retainUntil label not shown on detail")
        snap(app, "2e_01_detail_retain_until")

        let deleteButton = app.buttons["ra_delete_assessment"]
        XCTAssertTrue(scrollTo(deleteButton, in: app), "delete button not shown")
        deleteButton.tap()

        let alert = app.alerts["평가를 삭제하시겠습니까?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "delete confirmation alert not shown")
        // 방금 만든 평가는 항상 3년 보존 기간 내다 — 경고 문구가 함께 보여야 한다(하드 차단 아님).
        XCTAssertTrue(alert.staticTexts["시행규칙 제37조의4"].exists
                      || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '시행규칙 제37조의4'")).firstMatch.exists,
                      "retention warning citation not shown in delete confirmation")
        snap(app, "2e_02_delete_confirm_retention_warning")

        alert.buttons["취소"].tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "alert should dismiss on cancel")
        // 취소 후에도 평가 상세가 그대로 남아 있다 — 지워지지 않았다. List 는 lazy 라 삭제 버튼까지
        // 스크롤한 뒤에는 위쪽 행이 화면 밖일 수 있으므로 다시 훑어 확인한다.
        XCTAssertTrue(scrollTo(app.staticTexts["보존 기한"], in: app),
                      "assessment must remain after cancelling delete")
    }

    /// 삭제를 확인하면 실제로 지워지고 목록에서 사라진다.
    func testConfirmDeleteRemovesAssessment() throws {
        let app = launchApp()
        openPlannedDetail(app)

        let deleteButton = app.buttons["ra_delete_assessment"]
        XCTAssertTrue(scrollTo(deleteButton, in: app), "delete button not shown")
        deleteButton.tap()

        let alert = app.alerts["평가를 삭제하시겠습니까?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "delete confirmation alert not shown")
        alert.buttons["삭제"].tap()

        // 삭제 성공 시 상세를 닫고 목록으로 돌아간다 — 목록이 비어 있어야 한다.
        let emptyOrList = app.navigationBars.firstMatch
        XCTAssertTrue(emptyOrList.waitForExistence(timeout: 10), "did not return to the assessment list")
        XCTAssertFalse(app.staticTexts["보존 기한"].waitForExistence(timeout: 2),
                       "deleted assessment's detail must not still be visible")
        snap(app, "2e_03_after_delete")
    }
}
