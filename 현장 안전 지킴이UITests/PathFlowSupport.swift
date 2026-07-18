import XCTest

/// WO LEGAL-2d-PATH 로 생성 흐름이 바뀌면서 여러 UI 테스트가 공유하게 된 단계들.
/// (관할 확인 → 항목 작성 → 상세에서 시작)
extension XCTestCase {

    /// WO LEGAL-2d-PATH: 생성 화면은 이제 **관할 확인**을 요구하고, 저장 결과는 항상 `.planned` 다.
    /// 미국 관할을 고르면 일정이 필요 없어 생성 흐름이 가장 짧다.
    func pickUSJurisdiction(_ app: XCUIApplication) {
        let picker = app.buttons["ra_jurisdiction_picker"]
        // 긴 폼에서는 아래로 밀려 렌더되지 않을 수 있다 — 나타날 때까지 훑는다.
        if !picker.waitForExistence(timeout: 2) {
            for _ in 0..<6 { app.swipeUp(); if picker.exists { break } }
        }
        guard picker.exists else {
            XCTFail("jurisdiction picker not reachable — 관할 확인 없이는 저장할 수 없다")
            return
        }
        picker.tap()
        // 라벨은 표시 언어를 따르므로 한국어·영어 모두 받아준다.
        for label in ["미국", "United States"] {
            let option = app.buttons[label].firstMatch
            if option.waitForExistence(timeout: 2) { option.tap(); return }
        }
        XCTFail("US jurisdiction option not found in picker")
    }

    /// 항목 편집기를 채운다 — 작업·유해위험요인은 모두 비공백이어야 저장된다(Core 계약).
    func fillItem(_ app: XCUIApplication, task: String, hazard: String,
                  likelihood: String? = nil, severity: String? = nil, level: String? = nil) {
        let taskField = app.textFields["ra_item_task_field"]
        XCTAssertTrue(taskField.waitForExistence(timeout: 10), "task field not found")
        taskField.tap(); taskField.typeText(task)
        let hazardField = app.textFields["ra_item_hazard_field"]
        XCTAssertTrue(hazardField.waitForExistence(timeout: 5), "hazard field not found")
        hazardField.tap(); hazardField.typeText(hazard)
        if let likelihood { app.segmentedControls["ra_likelihood"].buttons[likelihood].firstMatch.tap() }
        if let severity { app.segmentedControls["ra_severity"].buttons[severity].firstMatch.tap() }
        if let level { app.buttons[level].firstMatch.tap() }
        app.buttons["ra_item_done"].tap()
    }

    /// planned 상세에서 평가를 시작한다(기준 확인 → inProgress).
    func startAssessmentFromDetail(_ app: XCUIApplication) {
        let start = app.buttons["ra_start_assessment"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "start button not shown on planned detail")
        start.tap()
        let confirm = app.buttons["ra_criteria_start_confirm"]
        if confirm.waitForExistence(timeout: 5) { confirm.tap() }
    }
}
