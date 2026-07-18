import XCTest

/// WO LEGAL-2d-PATH §6 — 관할 배선 + 항목 작성 경로의 종단 검증.
///
/// ① KR golden path: 계획 → 항목 작성 → 사전 공유 → 시작 → 결정 확인 → 확정 → 사후 공유 → 종결 표시.
/// ② KR 게이트: 사전 공유가 없으면 시작이 막히고, 유령 데이터가 남지 않는다.
/// ③ 관할 추천은 자동 확정되지 않는다(선택 전에는 저장 불가).
final class RiskAssessmentPathUITests: XCTestCase {

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

    /// 화면 밖 행은 lazy List 가 렌더하지 않는다 — 위아래로 훑어 찾는다.
    @discardableResult
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, swipes: Int = 6) -> Bool {
        if element.waitForExistence(timeout: 2) { return true }
        for _ in 0..<swipes { app.swipeUp(); if element.exists { return true } }
        for _ in 0..<(swipes * 2) { app.swipeDown(); if element.exists { return true } }
        return element.exists
    }

    private func openRAList(_ app: XCUIApplication) {
        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "home RA card not shown")
        card.tap()
    }

    /// 평가 계획 시트로 KR 평가를 만든다 (헤더만 — 항목은 상세에서 채운다).
    private func planKRAssessment(_ app: XCUIApplication) {
        openRAList(app)
        let planButton = app.buttons["ra_plan_toolbar"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 10), "plan toolbar button not shown")
        planButton.tap()

        let sitePicker = app.buttons["plan_site_picker"]
        XCTAssertTrue(sitePicker.waitForExistence(timeout: 10), "plan site picker not found")
        sitePicker.tap()
        app.buttons["테스트 현장"].firstMatch.tap()

        // 관할을 고르기 전에는 저장할 수 없다 — 추천만으로는 확정되지 않는다(§3).
        let save = app.buttons["plan_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "plan save button not found")
        XCTAssertFalse(save.isEnabled, "관할 확인 전에는 저장할 수 없어야 한다")

        let picker = app.buttons["ra_jurisdiction_picker"]
        XCTAssertTrue(scrollTo(picker, in: app), "jurisdiction picker not shown")
        picker.tap()
        app.buttons["대한민국"].firstMatch.tap()

        XCTAssertTrue(save.isEnabled, "관할을 고르면 저장할 수 있어야 한다")
        save.tap()

        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "planned row not shown")
        row.tap()
    }

    /// 상세에서 항목을 추가한다 (WO LEGAL-2d-PATH §4 — 계획 경로에도 작성 진입점이 있다).
    private func addItemFromDetail(_ app: XCUIApplication, task: String, hazard: String,
                                   likelihood: String, severity: String) {
        let add = app.buttons["ra_add_item"]
        XCTAssertTrue(scrollTo(add, in: app), "detail add-item entry point not shown")
        add.tap()
        let taskField = app.textFields["ra_item_task_field"]
        XCTAssertTrue(taskField.waitForExistence(timeout: 10), "task field not shown")
        taskField.tap(); taskField.typeText(task)
        let hazardField = app.textFields["ra_item_hazard_field"]
        XCTAssertTrue(hazardField.waitForExistence(timeout: 5), "hazard field not shown")
        hazardField.tap(); hazardField.typeText(hazard)
        app.segmentedControls["ra_likelihood"].buttons[likelihood].firstMatch.tap()
        app.segmentedControls["ra_severity"].buttons[severity].firstMatch.tap()
        app.buttons["ra_item_done"].tap()
    }

    private func recordSharing(_ app: XCUIApplication, entryPoint: String, target: String) {
        let button = app.buttons[entryPoint]
        XCTAssertTrue(scrollTo(button, in: app), "\(entryPoint) not shown")
        button.tap()
        let field = app.textFields["ra_sharing_target_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "sharing target field not shown")
        field.tap(); field.typeText(target)
        let save = app.buttons["ra_sharing_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "sharing save not shown")
        save.tap()
        if app.alerts.firstMatch.waitForExistence(timeout: 2) {
            XCTFail("sharing save failed: \(app.alerts.firstMatch.label)")
        }
    }

    // MARK: - ① KR golden path

    func testKRGoldenPathPlanToClosed() throws {
        let app = launchApp()
        planKRAssessment(app)
        snap(app, "path_01_kr_planned")

        // --- 항목 작성 (계획 상태에서) ---
        addItemFromDetail(app, task: "운반 작업", hazard: "협착", likelihood: "1", severity: "1")
        XCTAssertTrue(scrollTo(app.staticTexts["운반 작업"], in: app), "added item not shown")
        snap(app, "path_02_item_added_while_planned")

        // --- 사전 공유 없이는 시작이 막힌다 (KR 게이트) ---
        let start = app.buttons["ra_start_assessment"]
        XCTAssertTrue(scrollTo(start, in: app), "start button not shown")
        start.tap()
        let confirmStart = app.buttons["ra_criteria_start_confirm"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 5), "criteria sheet not shown")
        confirmStart.tap()

        // KR 게이트가 닫혀 있으므로 시작이 거부되고, 시트에 사유 알럿이 뜬다(화면은 닫히지 않는다).
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5),
                      "KR 평가는 사전 공유 없이 시작되면 안 되고, 그 사유를 알려야 한다")
        snap(app, "path_03_start_blocked_without_pre_sharing")
        alert.buttons.firstMatch.tap()
        // 시트를 닫고 상세로 돌아온다 (식별자로 확실히 잡는다).
        let cancel = app.buttons["ra_criteria_start_cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "criteria sheet cancel not found")
        cancel.tap()
        XCTAssertFalse(app.buttons["ra_criteria_start_confirm"].waitForExistence(timeout: 3),
                       "criteria sheet should be dismissed")
        // 여전히 planned — 시작 진입점이 그대로 남아 있다.
        XCTAssertTrue(scrollTo(app.buttons["ra_start_assessment"], in: app),
                      "게이트에 막힌 평가는 planned 로 남아야 한다")

        // --- 사전 공유 기록 → 시작 ---
        recordSharing(app, entryPoint: "ra_record_pre_sharing", target: "1공장 전 근로자")
        let start2 = app.buttons["ra_start_assessment"]
        XCTAssertTrue(scrollTo(start2, in: app), "start button not shown after pre-sharing")
        start2.tap()
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 5), "criteria sheet not reopened")
        confirmStart.tap()
        // 이번엔 게이트가 열려 있으므로 알럿 없이 시작돼야 한다.
        if app.alerts.firstMatch.waitForExistence(timeout: 3) {
            XCTFail("사전 공유가 있는데도 시작이 거부됐다: \(app.alerts.firstMatch.label)")
        }

        // --- 결정 확인 → 확정 ---
        let confirmDecision = app.buttons["ra_confirm_decision"].firstMatch
        XCTAssertTrue(scrollTo(confirmDecision, in: app), "decision confirm not shown (start failed?)")
        confirmDecision.tap()
        snap(app, "path_04_inprogress_confirmed")

        let finalize = app.buttons["ra_finalize_assessment"]
        XCTAssertTrue(scrollTo(finalize, in: app), "finalize button not shown")
        XCTAssertTrue(finalize.isEnabled, "모든 항목이 확인되면 확정할 수 있어야 한다")
        finalize.tap()

        // --- 사후 공유 → 종결 파생 표시 ---
        // 기준 초과 항목이 0건이므로 사후 공유만 기록되면 KR 종결 조건이 충족된다.
        XCTAssertTrue(scrollTo(app.descendants(matching: .any)["ra_closed_no"], in: app),
                      "사후 공유 전에는 아직 종결이 아니어야 한다")
        snap(app, "path_05_finalized_not_closed")

        recordSharing(app, entryPoint: "ra_record_post_sharing", target: "전 근로자")
        XCTAssertTrue(scrollTo(app.descendants(matching: .any)["ra_closed_yes"], in: app),
                      "현재 사후 공유가 있으면 종결로 표시돼야 한다")
        snap(app, "path_06_closed")
    }

    // MARK: - ② 항목 CRUD + 잠금

    func testItemEditableWhilePlannedAndLockedAfterFinalize() throws {
        let app = launchApp()
        planKRAssessment(app)

        addItemFromDetail(app, task: "굴착 작업", hazard: "붕괴", likelihood: "1", severity: "1")
        XCTAssertTrue(scrollTo(app.staticTexts["굴착 작업"], in: app), "item not added")

        // 계획 상태에서 항목을 수정할 수 있다 (행 스와이프 → 편집).
        // 행은 자체 식별자를 갖지 않는다(자식 버튼 식별자를 덮어쓰므로) — 항목 텍스트로 찾는다.
        let row = app.staticTexts["굴착 작업"].firstMatch
        XCTAssertTrue(scrollTo(row, in: app), "item row not shown")
        row.swipeLeft()
        let edit = app.buttons["ra_item_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "swipe edit action not shown while planned")
        edit.tap()
        let taskField = app.textFields["ra_item_task_field"]
        XCTAssertTrue(taskField.waitForExistence(timeout: 10), "item editor not shown")
        // 기존 텍스트가 있는 필드는 탭 위치에 따라 커서가 어디든 놓일 수 있다 — 전체 선택 후 새로 쓴다.
        taskField.tap()
        taskField.press(forDuration: 1.2)
        let selectAll = app.menuItems["전체 선택"].firstMatch
        if selectAll.waitForExistence(timeout: 3) { selectAll.tap() }
        taskField.typeText("굴착 2구역")
        app.buttons["ra_item_done"].tap()

        // 수정이 반영됐는지 — 새 문구가 보이고 옛 문구는 사라진다.
        let edited = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "2구역")).firstMatch
        XCTAssertTrue(scrollTo(edited, in: app), "edited item not shown")
        snap(app, "path_07_item_edited_while_planned")

        // 확정까지 진행하면 항목 편집 진입점이 사라진다(잠금).
        recordSharing(app, entryPoint: "ra_record_pre_sharing", target: "전 근로자")
        let start = app.buttons["ra_start_assessment"]
        XCTAssertTrue(scrollTo(start, in: app), "start not shown")
        start.tap()
        let confirmStart = app.buttons["ra_criteria_start_confirm"]
        if confirmStart.waitForExistence(timeout: 5) { confirmStart.tap() }
        let confirmDecision = app.buttons["ra_confirm_decision"].firstMatch
        XCTAssertTrue(scrollTo(confirmDecision, in: app), "decision confirm not shown")
        confirmDecision.tap()
        let finalize = app.buttons["ra_finalize_assessment"]
        XCTAssertTrue(scrollTo(finalize, in: app), "finalize not shown")
        finalize.tap()

        XCTAssertFalse(scrollTo(app.buttons["ra_add_item"], in: app, swipes: 4),
                       "finalized 평가에서는 항목 추가 진입점이 없어야 한다")
        // 스와이프해도 편집·삭제 액션이 없다 (항목 잠금).
        let lockedRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "2구역")).firstMatch
        if scrollTo(lockedRow, in: app) {
            lockedRow.swipeLeft()
            XCTAssertFalse(app.buttons["ra_item_edit"].waitForExistence(timeout: 3),
                           "finalized 평가에서는 항목 편집 액션이 없어야 한다")
        }
        snap(app, "path_08_items_locked_after_finalize")
    }
}
