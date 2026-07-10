import XCTest

/// Captures the App Store submission screenshots (WO-6b) on the iPad 13" simulator.
/// iPad automatically gets the NavigationSplitView shell (IPadRootView) purely from
/// horizontalSizeClass == .regular — no iPad-specific launch args needed.
final class AppStoreScreenshotsIPadUITests: XCTestCase {

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

    /// NOTE (WO-6b): a second "split 위험성평가" screenshot was attempted (sidebar →
    /// 위험성평가 → new-assessment button) but the create sheet reproducibly never
    /// presents on this iPad destination — neither `.tap()` nor a coordinate-based tap
    /// on `ra_new_button`/`ra_new_toolbar` opens it (confirmed via accessibility-tree
    /// dumps: the screen stays on the empty RA list, no sheet — not the paywall either,
    /// so it isn't a Pro-gating issue). This reproduces identically across multiple
    /// clean simulator erases, so it isn't a timing flake. Left as a follow-up; only the
    /// split-home capture (below) ships from this test.
    func testCaptureSplitHomeAndRiskAssessment() throws {
        let app = launch(pro: true)

        // Home (split view) → Start inspection → add one site → default recommended
        // scope (no need to touch it) → begin. Left in-progress on purpose — no item
        // marking needed for a populated "split home" screenshot.
        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '점검 시작'")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 20), "start-inspection button not found")
        start.tap()

        let addSite = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '새 현장 추가'")).firstMatch
        XCTAssertTrue(addSite.waitForExistence(timeout: 10), "add-site button not found")
        addSite.tap()
        let nameField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("본사 신축 현장")
        app.buttons.matching(NSPredicate(format: "label == '저장'")).firstMatch.tap()
        app.staticTexts["본사 신축 현장"].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch.tap()

        // Area — default skip.
        app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch.tap()

        // Template — first row, proceed.
        let templateRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '항목'")).firstMatch
        XCTAssertTrue(templateRow.waitForExistence(timeout: 5), "template row not found")
        templateRow.tap()
        app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch.tap()

        // Scope — recommended defaults are already applied on appear; just begin.
        let beginBtn = app.buttons.matching(NSPredicate(format: "label == '점검 시작'")).firstMatch
        XCTAssertTrue(beginBtn.waitForExistence(timeout: 5), "begin button not found")
        beginBtn.tap()

        // Reveal the sidebar (NavigationSplitView starts collapsed on first appearance)
        // so the screenshot shows the real split layout, not the detail-only column.
        let toggleSidebar = app.buttons["ToggleSidebar"]
        XCTAssertTrue(toggleSidebar.waitForExistence(timeout: 10), "sidebar toggle not found")
        toggleSidebar.tap()
        Thread.sleep(forTimeInterval: 2.5)   // let the reveal animation fully settle

        // Back on the split-view Home — capture.
        let inspectionRow = app.staticTexts["본사 신축 현장"].firstMatch
        XCTAssertTrue(inspectionRow.waitForExistence(timeout: 10), "inspection row not found on home")
        snap(app, "ipad-home")

        app.terminate()
    }
}
