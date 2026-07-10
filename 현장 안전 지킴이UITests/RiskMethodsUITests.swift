import XCTest

/// WO-2b: drives the two new methods on-device. JSA = ordered freq×severity steps;
/// checklist = 3-level with the "seed from inspection" entry. Screenshots attached.
final class RiskMethodsUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.uitestPro", "1",   // WO-10: Pro so the create gate opens
        ]
        app.launch()
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func openCreate(_ app: XCUIApplication) {
        let card = app.buttons["ra_home_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        card.tap()
        let newBtn = app.buttons["새 위험성평가"].firstMatch
        XCTAssertTrue(newBtn.waitForExistence(timeout: 10))
        newBtn.tap()
        XCTAssertTrue(app.buttons["ra_method_picker"].waitForExistence(timeout: 10))
    }

    private func selectMethod(_ app: XCUIApplication, _ label: String) {
        app.buttons["ra_method_picker"].tap()
        let option = app.buttons[label].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "method option \(label) not found")
        option.tap()
    }

    private func setFreqSeverity(_ app: XCUIApplication, _ likelihood: String, _ severity: String) {
        let lk = app.segmentedControls["ra_likelihood"]
        XCTAssertTrue(lk.waitForExistence(timeout: 10))
        lk.buttons[likelihood].tap()
        app.segmentedControls["ra_severity"].buttons[severity].tap()
    }

    private func typeTask(_ app: XCUIApplication, label: String, _ text: String) {
        let t = app.textFields[label]
        XCTAssertTrue(t.waitForExistence(timeout: 5), "task field \(label) not found")
        t.tap()
        t.typeText(text)
    }

    func testJsaOrderedSteps() throws {
        let app = launch()
        openCreate(app)
        selectMethod(app, "JSA/JHA")   // KO label (app runs in Korean)

        app.buttons["단계 추가"].tap()
        setFreqSeverity(app, "2", "2")                 // 4 → 보통
        typeTask(app, label: "작업 단계", "터파기 굴착")
        app.buttons["완료"].tap()

        app.buttons["단계 추가"].tap()
        setFreqSeverity(app, "3", "3")                 // 9 → 높음
        typeTask(app, label: "작업 단계", "자재 양중")
        app.buttons["완료"].tap()

        snap(app, "jsa_01_create_steps")
        app.buttons["저장"].tap()

        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.staticTexts["터파기 굴착"].waitForExistence(timeout: 10))
        snap(app, "jsa_02_detail")
    }

    func testChecklistMethodWithSeedEntry() throws {
        let app = launch()
        openCreate(app)
        selectMethod(app, "체크리스트법")

        XCTAssertTrue(app.buttons["점검에서 가져오기"].waitForExistence(timeout: 5))
        snap(app, "checklist_01_create")

        app.buttons["점검에서 가져오기"].tap()
        // Fresh store → empty inspection picker (proves the picker works).
        XCTAssertTrue(app.staticTexts["완료된 점검이 없습니다"].waitForExistence(timeout: 10))
        snap(app, "checklist_02_inspection_picker")
        // Disambiguate: both the create sheet and the picker have a 취소 button.
        app.navigationBars["완료된 점검 선택"].buttons["취소"].tap()

        // Add a 3-level item manually (checklist uses direct 상/중/하).
        app.buttons["항목 추가"].tap()
        let medium = app.buttons["보통"].firstMatch
        XCTAssertTrue(medium.waitForExistence(timeout: 10))
        medium.tap()
        typeTask(app, label: "공정·작업", "전기 안전")
        app.buttons["완료"].tap()

        app.buttons["저장"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10))
        snap(app, "checklist_03_list")
    }
}
