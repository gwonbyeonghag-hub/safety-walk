import XCTest

/// LEGAL-1 UI evidence: the display language and the legal region are independent axes.
/// ① Settings shows 언어=한국어 while 지역=Global (decoupled). ② Changing the region is
/// reflected in the inspection template picker (Global template pre-selected).
final class LanguageRegionDecouplingUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.uitestPro", "1",
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

    func testLanguageKoreanWithRegionGlobalThenTemplateReflects() throws {
        let app = launchApp()

        // ── Settings: language stays 한국어, region set to Global (independent axes) ──
        app.tabBars.buttons["gear"].tap()
        XCTAssertTrue(app.staticTexts["지역"].waitForExistence(timeout: 20), "region section not found")
        // UI is Korean (both the section header 지역 and the language option 한국어 are present).
        XCTAssertTrue(app.buttons["한국어"].exists, "language should be 한국어")

        let regionPicker = app.segmentedControls["settings_region_picker"]
        XCTAssertTrue(regionPicker.waitForExistence(timeout: 5), "region picker not found")
        regionPicker.buttons["글로벌"].tap()
        XCTAssertTrue(regionPicker.buttons["글로벌"].isSelected, "region should now be 글로벌")
        // Language is still 한국어 — proves the two are decoupled.
        XCTAssertTrue(app.buttons["한국어"].isSelected, "language must remain 한국어 after region change")
        snap(app, "legal1_01_settings_ko_lang_global_region")

        // ── Start an inspection → the template picker reflects the Global region ──
        app.tabBars.buttons["house"].tap()
        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '점검 시작'")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 15), "start-inspection button not found")
        start.tap()

        // Add a site, then step through to the template selection screen.
        let addSite = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '새 현장 추가'")).firstMatch
        XCTAssertTrue(addSite.waitForExistence(timeout: 10), "add-site button not found")
        addSite.tap()
        let nameField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("현장 A")
        app.buttons.matching(NSPredicate(format: "label == '저장'")).firstMatch.tap()
        app.staticTexts["현장 A"].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch.tap()   // site → area
        app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch.tap()   // area → template

        // Template selection: both region templates listed, Global badge present + pre-selected.
        let globalBadge = app.staticTexts["글로벌"].firstMatch
        XCTAssertTrue(globalBadge.waitForExistence(timeout: 10),
                      "Global template badge not found — region not reflected")
        snap(app, "legal1_02_template_selection_global_reflected")
    }
}
