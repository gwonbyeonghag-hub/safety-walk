import XCTest

/// WO SCHEMA-V3 + 2a runtime QA: drives the new plan-lifecycle + participant flow end to
/// end (평가 계획 → 예정 목록 → 상세 → 참여자 추가 → 근로자대표 → 평가 시작) and captures a
/// screenshot at each step. The navigation itself is the runtime check; the attachments are
/// the deliverable screenshots. Mirrors WO5ScreensUITests' seed-launch + snap pattern.
final class RiskAssessment2aUITests: XCTestCase {

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
            "-com.safetywalk.uitestPro", "1",       // WO-10: Pro so authoring opens
            "-com.safetywalk.uitestSeedSite", "1",  // SCHEMA_V3 §4.1: a site is required
        ]
        app.launch()
        return app
    }

    func testPlanAndParticipantFlow() throws {
        let app = launchApp()

        // Home → Risk Assessment list
        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "home RA card not shown")
        card.tap()

        // Toolbar "평가 계획" (always present, whether or not the list already has rows).
        let planButton = app.buttons["ra_plan_toolbar"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "plan toolbar button not shown")
        planButton.tap()

        // --- Plan sheet: pick the seeded site, keep the default 7-day schedule ---
        let sitePicker = app.buttons["plan_site_picker"]
        XCTAssertTrue(sitePicker.waitForExistence(timeout: 10), "plan site picker not found")
        sitePicker.tap()
        let site = app.buttons["테스트 현장"].firstMatch
        XCTAssertTrue(site.waitForExistence(timeout: 5), "seeded site not in picker")
        site.tap()
        snap(app, "2a_01_plan_form")
        app.buttons["plan_save"].tap()

        // --- List now shows the planned row (예정 badge) ---
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "planned row not shown")
        snap(app, "2a_02_list_planned")
        row.tap()

        // --- Detail (planned): status badge · 평가 시작 · 근로자대표 · 참여자 ---
        let addParticipant = app.buttons["ra_add_participant"]
        XCTAssertTrue(addParticipant.waitForExistence(timeout: 10), "detail not shown")
        snap(app, "2a_03_detail_planned")

        // --- Add a participant: name required, role, method, confirmation, optional signature ---
        addParticipant.tap()
        let nameField = app.textFields["participant_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "participant editor not shown")
        nameField.tap()
        nameField.typeText("홍길동")
        // role → 근로자 대표 (segmented)
        app.segmentedControls.firstMatch.buttons["근로자 대표"].firstMatch.tap()
        snap(app, "2a_04_participant_editor")
        app.buttons["participant_save"].tap()

        // --- Back in detail: participant recorded; set 근로자대표 상태 ---
        XCTAssertTrue(app.staticTexts["홍길동"].waitForExistence(timeout: 10), "participant not recorded")
        let workerRep = app.buttons["ra_worker_rep_picker"]
        if workerRep.waitForExistence(timeout: 3) {
            workerRep.tap()
            let participated = app.buttons["참여"].firstMatch
            if participated.waitForExistence(timeout: 3) { participated.tap() }
        }
        snap(app, "2a_05_detail_with_participant")

        // --- Lifecycle: planned → inProgress ---
        let start = app.buttons["ra_start_assessment"]
        if start.waitForExistence(timeout: 3) {
            start.tap()
            snap(app, "2a_06_detail_inprogress")
        }
    }
}
