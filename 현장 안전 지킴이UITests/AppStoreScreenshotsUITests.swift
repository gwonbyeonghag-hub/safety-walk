import XCTest
import StoreKitTest

/// Captures the App Store submission screenshots (WO-6b) on the iPhone 6.9" simulator.
/// Builds real, populated data through the actual UI (no seed hook exists on iOS) and
/// snaps each screen via `XCUIScreenshot` — no host-screen coordinate clicks, only
/// accessibility-driven taps inside the simulator (per the WO-11 coordinate-click ban).
final class AppStoreScreenshotsUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func launch(lang: String = "ko", mode: String = "light", pro: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.appLanguage", lang,
            "-com.safetywalk.appearanceMode", mode,
            "-com.safetywalk.uitestPro", pro ? "1" : "0",
        ]
        app.launch()
        return app
    }

    // MARK: - Photo picker (system PHPicker) — accessibility taps only, no coordinates.

    /// Taps the given photo-attach button, waits for the system Photos grid to finish
    /// loading (async fetch — ~5s on simulator), then taps the most-recent photo.
    /// `simctl addmedia` seeds two demo photos before the test run; the grid sorts
    /// newest-first, so index 0 is always one of the seeded images.
    private func attachPhoto(_ app: XCUIApplication, tapping button: XCUIElement) {
        button.tap()
        let firstPhoto = app.images
            .matching(NSPredicate(format: "identifier == 'PXGGridLayout-Info'"))
            .element(boundBy: 0)
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 10), "photo grid did not load")
        firstPhoto.tap()
        // Picker dismiss + item load-back is async; give it a moment before the next tap.
        Thread.sleep(forTimeInterval: 1.5)
    }

    // MARK: - Flow helpers

    private func addSiteInStartFlow(_ app: XCUIApplication, name: String) {
        let addSite = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '새 현장 추가'")).firstMatch
        XCTAssertTrue(addSite.waitForExistence(timeout: 10), "add-site button not found")
        addSite.tap()
        let nameField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        app.buttons.matching(NSPredicate(format: "label == '저장'")).firstMatch.tap()
        app.staticTexts[name].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch.tap()
    }

    /// Starts an inspection scoped to exactly the given category labels (default
    /// recommendation is cleared first, then only the requested categories re-enabled) —
    /// keeps the number of checklist items small and deterministic for the screenshot flow.
    private func startInspection(_ app: XCUIApplication, siteName: String, categories: [String]) {
        addSiteInStartFlow(app, name: siteName)

        // Area — default is "skip", just proceed.
        app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch.tap()

        // Template — pick the first (only) template, proceed.
        let templateRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '항목'")).firstMatch
        XCTAssertTrue(templateRow.waitForExistence(timeout: 5), "template row not found")
        templateRow.tap()
        app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch.tap()

        // Scope — clear the recommended defaults, then enable exactly `categories`.
        let clearAll = app.buttons.matching(NSPredicate(format: "label == '전체 해제'")).firstMatch
        XCTAssertTrue(clearAll.waitForExistence(timeout: 5), "clear-all not found")
        clearAll.tap()
        for category in categories {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", category)).firstMatch.tap()
        }
        app.buttons.matching(NSPredicate(format: "label == '점검 시작'")).firstMatch.tap()
    }

    private func resultButton(_ app: XCUIApplication, _ label: String, index: Int) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).element(boundBy: index)
    }

    // MARK: - Phase A: build populated data + capture checklist/hazard/report/home/RA-input

    func testBuildDataAndCaptureCoreScreens() throws {
        let app = launch(pro: true)

        // Home → Start inspection → site "샘플 물류센터" → only 일반 안전 + 보호구 (3 items each).
        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '점검 시작'")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 20), "start-inspection button not found")
        start.tap()
        startInspection(app, siteName: "샘플 물류센터", categories: ["일반 안전", "보호구"])

        // Back on Home — the new in-progress inspection appears in "최근 점검".
        let inspectionRow = app.staticTexts["샘플 물류센터"].firstMatch
        XCTAssertTrue(inspectionRow.waitForExistence(timeout: 10), "inspection row not found on home")
        inspectionRow.tap()

        // InspectionDetailView → continue.
        let cont = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '점검 계속'")).firstMatch
        XCTAssertTrue(cont.waitForExistence(timeout: 10), "continue button not found")
        cont.tap()

        // ChecklistView → open category "일반 안전" (3 items).
        let generalCategory = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '일반 안전'")).firstMatch
        XCTAssertTrue(generalCategory.waitForExistence(timeout: 10), "일반 안전 category not found")
        generalCategory.tap()

        // item1 = 적합, item2 = 부적합 (+ photo + hazard), item3 = 적합.
        resultButton(app, "적합", index: 0).tap()
        resultButton(app, "부적합", index: 1).tap()
        resultButton(app, "적합", index: 2).tap()

        // item2's own photo-attach button — item1/item3 are also 적합 so 3 "사진 첨부"
        // buttons exist now; item2 is the middle one (index 1).
        let photoButtons = app.buttons.matching(NSPredicate(format: "label == '사진 첨부'"))
        XCTAssertTrue(photoButtons.element(boundBy: 1).waitForExistence(timeout: 5), "item2 photo button not found")
        attachPhoto(app, tapping: photoButtons.element(boundBy: 1))

        // Register the hazard from item2 (the only Fail item → only one such button).
        let registerHazard = app.buttons.matching(NSPredicate(format: "label == '위험요인 등록'")).firstMatch
        XCTAssertTrue(registerHazard.waitForExistence(timeout: 5), "register-hazard button not found")
        registerHazard.tap()

        // HazardRegistrationView: risk = 높음, description, photo, save.
        app.buttons.matching(NSPredicate(format: "label == '높음'")).firstMatch.tap()
        let desc = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] '위험'")).firstMatch
        XCTAssertTrue(desc.waitForExistence(timeout: 5), "hazard description field not found")
        desc.tap()
        desc.typeText("안전난간 미설치로 추락 위험이 있음")
        let hazardPhotoBtn = app.buttons.matching(NSPredicate(format: "label == '사진 첨부'")).firstMatch
        XCTAssertTrue(hazardPhotoBtn.waitForExistence(timeout: 5), "hazard photo button not found")
        attachPhoto(app, tapping: hazardPhotoBtn)
        app.buttons.matching(NSPredicate(format: "label == '저장'")).firstMatch.tap()

        // Back in the category detail — item2 now shows "위험요인 연결됨". Capture "체크리스트".
        XCTAssertTrue(app.staticTexts["위험요인 연결됨"].waitForExistence(timeout: 10), "hazard link not shown")
        snap(app, "iphone-checklist")

        // Back to ChecklistView → open "보호구" → mark all 3 적합 → back → complete.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ppeCategory = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '보호구'")).firstMatch
        XCTAssertTrue(ppeCategory.waitForExistence(timeout: 10), "보호구 category not found")
        ppeCategory.tap()
        for i in 0..<3 {
            resultButton(app, "적합", index: i).tap()
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let completeBtn = app.buttons.matching(NSPredicate(format: "label == '점검 완료'")).firstMatch
        XCTAssertTrue(completeBtn.waitForExistence(timeout: 10), "complete button not found")
        XCTAssertTrue(completeBtn.isEnabled, "complete button should be enabled once all items are checked")
        completeBtn.tap()

        // InspectionSummaryView appears — capture "리포트".
        XCTAssertTrue(app.staticTexts["샘플 물류센터"].waitForExistence(timeout: 10), "summary not shown")
        snap(app, "iphone-report")
        app.buttons.matching(NSPredicate(format: "label == '완료'")).firstMatch.tap()

        // Back to Home root (tapping the already-selected tab pops its nav stack to root).
        let homeTab = app.tabBars.buttons["house"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
        homeTab.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '점검 시작'")).firstMatch.waitForExistence(timeout: 10))
        snap(app, "iphone-home")

        // Hazards tab — shows the registered hazard with photo + 높음 risk chip.
        app.tabBars.buttons["exclamationmark.triangle"].tap()
        XCTAssertTrue(app.staticTexts["안전난간 미설치로 추락 위험이 있음"].waitForExistence(timeout: 10), "hazard row not shown")
        snap(app, "iphone-hazard")

        // Home → Risk Assessment → new → one item (before saving) → capture "평가입력".
        app.tabBars.buttons["house"].tap()
        let raCard = app.buttons["ra_home_card"]
        XCTAssertTrue(raCard.waitForExistence(timeout: 10))
        raCard.tap()
        app.buttons["ra_new_toolbar"].tap()
        let addItem = app.buttons.matching(NSPredicate(format: "label == '항목 추가'")).firstMatch
        XCTAssertTrue(addItem.waitForExistence(timeout: 10))
        addItem.tap()
        let lk = app.segmentedControls["ra_likelihood"]
        XCTAssertTrue(lk.waitForExistence(timeout: 10))
        lk.buttons["2"].tap()
        app.segmentedControls["ra_severity"].buttons["3"].tap()
        let task = app.textFields["공정·작업"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        task.typeText("고소 작업 안전대 체결")
        app.buttons.matching(NSPredicate(format: "label == '완료'")).firstMatch.tap()
        snap(app, "iphone-risk-assessment")

        app.terminate()
    }

    // MARK: - Phase B: relaunch in dark mode, same persisted data — home only.

    func testCaptureHomeDark() throws {
        let app = launch(mode: "dark", pro: true)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '점검 시작'")).firstMatch.waitForExistence(timeout: 20))
        snap(app, "iphone-home-dark")
        app.terminate()
    }

    // MARK: - Phase C: paywall (non-subscriber, real StoreKit prices), light + dark.

    private func tapNewAssessment(_ app: XCUIApplication) {
        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "home RA card not found")
        card.tap()
        let newBtn = app.buttons["ra_new_toolbar"]
        XCTAssertTrue(newBtn.waitForExistence(timeout: 10), "RA new button not found")
        newBtn.tap()
    }

    func testCapturePaywall() throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.resetToDefaultState()
        session.clearTransactions()
        addTeardownBlock { session.clearTransactions() }

        for mode in ["light", "dark"] {
            let app = launch(mode: mode, pro: false)
            tapNewAssessment(app)
            XCTAssertTrue(app.buttons["paywall_close"].waitForExistence(timeout: 15), "paywall not shown (\(mode))")
            snap(app, "iphone-paywall-\(mode)")
            app.terminate()
        }
    }
}
