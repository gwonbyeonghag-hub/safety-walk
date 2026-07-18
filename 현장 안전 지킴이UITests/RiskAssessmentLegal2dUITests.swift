import XCTest

/// WO LEGAL-2d runtime QA: drives the full 공유 기록 + 평가 확정 lifecycle on the simulator —
/// 평가 계획 → 사전(일정) 공유 기록 → 평가 시작 → 항목 결정 확인 → 평가 확정 → 사후(결과) 공유 기록 →
/// 공유 이력 → 그 시점의 불변 snapshot 상세. Screenshots at each state double as the design-QA artifact.
/// Mirrors RiskAssessment2aUITests' plan-sheet entry and RiskAssessmentLegal2cUITests' seed-launch + snap.
final class RiskAssessmentLegal2dUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func launchApp(appearance: String = "light",
                           language: String? = nil,
                           contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-com.safetywalk.appearanceMode", appearance,
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.uitestPro", "1",       // Pro so authoring opens
            "-com.safetywalk.uitestSeedSite", "1",  // SCHEMA_V3 §4.1: a site is required
        ]
        if let language { app.launchArguments += ["-com.safetywalk.appLanguage", language] }
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    /// SwiftUI List 는 lazy 라 화면 밖 행은 아예 렌더되지 않는다. 아래로 훑고 못 찾으면 위로 되돌아가며
    /// 찾으므로, 대상이 화면 어디에 있든 같은 헬퍼로 단언할 수 있다.
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

    /// 평가 계획(planned) 상세까지 진입 — 사전 공유의 진입점.
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

    /// 공유 기록 시트를 채워 저장한다. 시점은 진입점이 정하므로 시트에서 고를 수 없다.
    private func recordSharing(_ app: XCUIApplication, target: String) {
        // 컨테이너와 그 자식이 같은 식별자를 물려받으므로 firstMatch 로 단일 요소를 고른다.
        let phaseRow = app.descendants(matching: .any)["ra_sharing_phase_fixed"].firstMatch
        XCTAssertTrue(phaseRow.waitForExistence(timeout: 10), "sharing sheet not shown")
        // 시점을 바꾸는 컨트롤이 존재하지 않는지 확인 (진입점 고정).
        XCTAssertFalse(app.buttons["ra_sharing_phase_picker"].exists,
                       "phase must be fixed by the entry point, not user-selectable")

        let targetField = app.textFields["ra_sharing_target_field"]
        XCTAssertTrue(targetField.waitForExistence(timeout: 10), "target field not shown")
        targetField.tap()
        targetField.typeText(target)

        // 저장은 툴바에 있어 폼이 아무리 길어져도(큰 글자 포함) 항상 도달 가능해야 한다.
        let save = app.buttons["ra_sharing_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5),
                      "save button must stay reachable regardless of Dynamic Type size")
        XCTAssertTrue(save.isEnabled, "save must enable once target + owner are filled")
        save.tap()

        // 저장 실패는 화면을 닫지 않고 알럿만 띄운다 — 그 경우 실패 사유를 그대로 드러낸다.
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            XCTFail("sharing save failed: \(alert.label) / \(alert.staticTexts.allElementsBoundByIndex.map(\.label))")
        }
    }

    /// 새 평가(create) 경로: 항목을 함께 작성해 planned 평가를 만든 뒤 상세에서 시작한다
    /// (WO LEGAL-2d-PATH §2 — 두 생성 경로 모두 planned 를 거친다).
    private func createInProgressWithItem(_ app: XCUIApplication) {
        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "home RA card not shown")
        card.tap()

        let newBtn = app.buttons["새 위험성평가"].firstMatch
        XCTAssertTrue(newBtn.waitForExistence(timeout: 10), "new-assessment button not found")
        newBtn.tap()

        let sitePicker = app.buttons["ra_site_picker"]
        XCTAssertTrue(sitePicker.waitForExistence(timeout: 10), "create site picker not found")
        sitePicker.tap()
        app.buttons["테스트 현장"].firstMatch.tap()
        pickUSJurisdiction(app)   // WO LEGAL-2d-PATH §3: 관할 확인 필수

        // 1×1 = 1 → 기준 이내라 필수 개선조치가 없다 → 결정 확인만으로 확정 가능해진다.
        app.buttons["항목 추가"].tap()
        fillItem(app, task: "운반 작업", hazard: "협착", likelihood: "1", severity: "1")

        let save = app.buttons["저장"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "save button not found")
        save.tap()

        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "assessment row not shown")
        row.tap()
        // WO LEGAL-2d-PATH: 생성 결과는 planned — 상세에서 시작해야 inProgress 가 된다.
        startAssessmentFromDetail(app)
    }

    /// 사전(일정) 공유 → 평가 시작. 계획 경로의 진입점 고정과 이력 기록을 검증한다.
    func testPreSharingThenStart() throws {
        let app = launchApp()
        openPlannedDetail(app)

        let preButton = app.buttons["ra_record_pre_sharing"]
        XCTAssertTrue(scrollTo(preButton, in: app), "pre-sharing entry point not shown")
        snap(app, "2d_01_detail_planned")
        preButton.tap()
        snap(app, "2d_02_pre_sharing_sheet")
        recordSharing(app, target: "1공장 전 근로자")

        XCTAssertTrue(scrollTo(app.staticTexts["1공장 전 근로자"], in: app),
                      "pre-sharing record not shown in history")
        snap(app, "2d_03_history_after_pre")

        // planned → inProgress. 사후 공유 진입점은 아직 없어야 한다(시점 게이트).
        let start = app.buttons["ra_start_assessment"]
        XCTAssertTrue(scrollTo(start, in: app), "start button not shown")
        start.tap()
        let confirmStart = app.buttons["ra_criteria_start_confirm"]
        if confirmStart.waitForExistence(timeout: 5) { confirmStart.tap() }

        XCTAssertFalse(app.buttons["ra_record_post_sharing"].waitForExistence(timeout: 3),
                       "post-sharing must not be reachable before the assessment is finalized")
        snap(app, "2d_04_detail_inprogress")
    }

    /// 평가 확정 → 사후(결과) 공유 → 이력 → 그 시점 snapshot 상세.
    func testFinalizeThenPostSharingAndSnapshot() throws {
        let app = launchApp()
        createInProgressWithItem(app)

        // 결정 확인 → 확정 가능.
        let confirmDecision = app.buttons["ra_confirm_decision"].firstMatch
        XCTAssertTrue(scrollTo(confirmDecision, in: app), "decision confirm button not shown")
        confirmDecision.tap()
        snap(app, "2d_05_detail_inprogress_ready")

        // --- 평가 확정 ---
        let finalize = app.buttons["ra_finalize_assessment"]
        XCTAssertTrue(scrollTo(finalize, in: app), "finalize button not shown")
        XCTAssertTrue(finalize.isEnabled, "finalize must enable once every item is confirmed")
        finalize.tap()
        snap(app, "2d_06_detail_finalized")

        // --- finalized: 사후 결과 공유 기록 ---
        let postButton = app.buttons["ra_record_post_sharing"]
        XCTAssertTrue(scrollTo(postButton, in: app),
                      "post-sharing entry point not shown after finalize")
        postButton.tap()
        snap(app, "2d_07_post_sharing_sheet")
        recordSharing(app, target: "협력사 포함 전원")

        // --- 이력 → 스냅샷 상세 ---
        XCTAssertTrue(scrollTo(app.staticTexts["협력사 포함 전원"], in: app),
                      "post-sharing record not shown in history")
        snap(app, "2d_08_history_after_post")

        let rows = app.buttons.matching(identifier: "ra_sharing_history_row")
        XCTAssertGreaterThanOrEqual(rows.count, 1, "history must list the recorded share")
        rows.element(boundBy: 0).tap()

        XCTAssertTrue(app.navigationBars["공유 당시 내용"].waitForExistence(timeout: 10),
                      "snapshot detail not shown")
        XCTAssertFalse(app.descendants(matching: .any)["ra_snapshot_unreadable"].exists,
                       "a freshly recorded snapshot must decode (no fail-closed error state)")
        XCTAssertTrue(app.staticTexts["운반 작업"].waitForExistence(timeout: 5),
                      "snapshot detail must show the item as shared")
        snap(app, "2d_09_snapshot_detail")
    }

    /// 다크 모드 · 긴 영문 문구 · 접근성 XXXL 텍스트 스모크 (WO LEGAL-2d §8). 공유 시트와 이력이
    /// 잘리거나 겹치지 않고 렌더되는지, 저장 경로가 언어·글자 크기와 무관하게 동작하는지 확인한다.
    func testDarkModeEnglishLargeTextSmoke() throws {
        let app = launchApp(appearance: "dark", language: "en",
                            contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        openPlannedDetail(app)

        let preButton = app.buttons["ra_record_pre_sharing"]
        XCTAssertTrue(scrollTo(preButton, in: app), "pre-sharing entry point not shown (dark/en/XXXL)")
        snap(app, "2d_10_dark_en_xxxl_detail")
        preButton.tap()

        // 시트가 열리고 저장까지 도달하면 레이아웃이 상호작용을 막지 않았다는 뜻이다.
        snap(app, "2d_11_dark_en_xxxl_sheet")
        recordSharing(app, target: "All workers on site")

        XCTAssertTrue(scrollTo(app.staticTexts["All workers on site"], in: app),
                      "sharing record not shown in history (dark/en/XXXL)")
        snap(app, "2d_12_dark_en_xxxl_history")
    }
}
