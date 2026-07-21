import XCTest

/// WO LEGAL-TBM-2 golden path: 생성 → 참석자 추가(서명 포함) → 진행(conduct) → 확정(finalize).
/// Runs on iPhone 16 / iOS 18.6 only (uitest-simulator-destination 메모 — iOS 26.5 시뮬레이터의
/// 접근성 계층이 깨져 있다).
final class SafetyBriefingUITests: XCTestCase {

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
            "-com.safetywalk.uitestSeedSite", "1",  // SCHEMA_V3 §4.1: Site 필수
        ]
        app.launch()
        return app
    }

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

    func testCreateAttendSignConductFinalize() throws {
        let app = launchApp()

        // Home → TBM Safety Briefing list
        let card = app.buttons["tbm_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "home TBM card not shown")
        card.tap()

        let newToolbar = app.buttons["tbm_new_toolbar"]
        XCTAssertTrue(newToolbar.waitForExistence(timeout: 10), "new toolbar button not shown")
        newToolbar.tap()

        // --- Create sheet: task description + seeded site (Site 는 필수) ---
        let taskField = app.textFields["tbm_task_description"]
        XCTAssertTrue(taskField.waitForExistence(timeout: 10), "create form not shown")
        taskField.tap()
        taskField.typeText("굴착 작업 TBM")

        let sitePicker = app.buttons["tbm_site_picker"]
        XCTAssertTrue(sitePicker.waitForExistence(timeout: 5), "site picker not found")
        sitePicker.tap()
        let site = app.buttons["테스트 현장"].firstMatch
        XCTAssertTrue(site.waitForExistence(timeout: 5), "seeded site not in picker")
        site.tap()
        snap(app, "tbm_01_create_form")

        let save = app.buttons["tbm_save"]
        XCTAssertTrue(save.isEnabled, "save should be enabled once Site is selected")
        save.tap()

        // --- List now shows the draft row ---
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "draft row not shown")
        snap(app, "tbm_02_list_draft")
        row.tap()

        // --- Detail (draft): add a participant with a signature ---
        let addParticipant = app.buttons["tbm_add_participant"]
        XCTAssertTrue(addParticipant.waitForExistence(timeout: 10), "detail not shown")
        snap(app, "tbm_03_detail_draft")
        addParticipant.tap()

        let nameField = app.textFields["tbm_participant_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "participant editor not shown")
        nameField.tap()
        nameField.typeText("홍길동")

        // 서명 — signature_pad 는 `DragGesture(minimumDistance: 0)`이라 탭 한 번으로도 점 하나가
        // strokes 에 기록된다(SignaturePad.add(_:to:) 의 "점 하나 = 짧은 점" 분기). 좌표 기반
        // press-drag 는 이 pad 를 감싼 Form 의 스크롤 팬 제스처와 경합해 실기(시뮬레이터)에서 전혀
        // 발동하지 않는 경우가 있었다 — 순수 탭은 그 경합이 없다.
        let pad = app.descendants(matching: .any)["signature_pad"].firstMatch
        XCTAssertTrue(pad.waitForExistence(timeout: 5), "signature pad not found")
        pad.tap()
        XCTAssertTrue(app.buttons["지우기"].waitForExistence(timeout: 5),
                      "clear button should appear once a stroke is drawn — signature not captured")
        snap(app, "tbm_04_participant_signed")

        app.buttons["tbm_participant_save"].tap()

        // --- Back in detail: participant recorded with a captured-signature indicator ---
        XCTAssertTrue(app.staticTexts["홍길동"].waitForExistence(timeout: 10), "participant not recorded")
        snap(app, "tbm_05_detail_with_participant")

        // --- draft → conducted: type 전달내용, then 진행 ---
        let contentEditor = app.textViews["tbm_content_editor"]
        XCTAssertTrue(scrollTo(contentEditor, in: app), "content editor not reachable")
        contentEditor.tap()
        contentEditor.typeText("오늘 작업의 위험요인과 안전조치를 전달했습니다.")

        let conduct = app.buttons["tbm_conduct"]
        XCTAssertTrue(scrollTo(conduct, in: app), "conduct button not reachable")
        XCTAssertTrue(conduct.isEnabled, "conduct should be enabled once content is non-blank")
        conduct.tap()

        // --- conducted: content locked, finalize button appears ---
        let finalize = app.buttons["tbm_finalize"]
        XCTAssertTrue(scrollTo(finalize, in: app), "finalize button not shown after conduct")
        snap(app, "tbm_06_detail_conducted")

        // --- conducted → finalized ---
        finalize.tap()

        // --- finalized: participants locked (no add button), status shows 확정됨 ---
        XCTAssertTrue(scrollTo(app.staticTexts["확정됨"], in: app), "finalized status not shown")
        XCTAssertFalse(app.buttons["tbm_add_participant"].exists,
                       "participants must lock after finalize")
        snap(app, "tbm_07_detail_finalized")
    }

    func testDraftCancelRecordsReasonAndLeavesFinalizedUnreachable() throws {
        let app = launchApp()

        app.buttons["tbm_home_card"].tap()
        app.buttons["tbm_new_toolbar"].tap()

        let taskField = app.textFields["tbm_task_description"]
        XCTAssertTrue(taskField.waitForExistence(timeout: 10))
        taskField.tap()
        taskField.typeText("취소 테스트")
        app.buttons["tbm_site_picker"].tap()
        app.buttons["테스트 현장"].firstMatch.tap()
        app.buttons["tbm_save"].tap()

        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        let cancelButton = app.buttons["tbm_cancel"]
        XCTAssertTrue(scrollTo(cancelButton, in: app), "cancel button not reachable")
        cancelButton.tap()

        let reasonField = app.textFields["tbm_cancel_reason"]
        XCTAssertTrue(reasonField.waitForExistence(timeout: 10), "cancel sheet not shown")
        reasonField.tap()
        reasonField.typeText("현장 사정으로 취소")

        let confirm = app.buttons["tbm_cancel_confirm"]
        XCTAssertTrue(confirm.isEnabled, "confirm should enable once a reason is entered")
        confirm.tap()

        XCTAssertTrue(scrollTo(app.staticTexts["취소됨"], in: app), "cancelled status not shown")
        XCTAssertTrue(scrollTo(app.staticTexts["현장 사정으로 취소"], in: app), "cancellation reason not shown")
        // draft/conducted 전용 동작들은 취소 후 더 이상 보이지 않는다.
        XCTAssertFalse(app.buttons["tbm_conduct"].exists, "conduct must not be offered after cancel")
        XCTAssertFalse(app.buttons["tbm_cancel"].exists, "cancel must not be offered again on a cancelled record")
    }
}
