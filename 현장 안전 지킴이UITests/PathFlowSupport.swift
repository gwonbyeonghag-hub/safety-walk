import XCTest

/// WO LEGAL-2d-PATH 로 생성 흐름이 바뀌면서 여러 UI 테스트가 공유하게 된 단계들.
/// (관할 확인 → 항목 작성 → 상세에서 시작)
extension XCTestCase {

    /// WO LEGAL-2d-PATH: 생성 화면은 이제 **관할 확인**을 요구하고, 저장 결과는 항상 `.planned` 다.
    /// 미국 관할을 고르면 일정이 필요 없어 생성 흐름이 가장 짧다.
    /// WO LEGAL-3A: US 관할은 업종 확인도 함께 요구하므로, 선택 즉시 나타나는 업종 피커도 채운다.
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
        var found = false
        for label in ["미국", "United States"] {
            let option = app.buttons[label].firstMatch
            if option.waitForExistence(timeout: 2) { option.tap(); found = true; break }
        }
        guard found else {
            XCTFail("US jurisdiction option not found in picker")
            return
        }
        pickIndustry(app)
    }

    /// US 관할에서만 나타나는 업종 피커를 채운다(WO LEGAL-3A). 기본값으로 일반산업을 고른다.
    func pickIndustry(_ app: XCUIApplication) {
        let picker = app.buttons["ra_industry_picker"]
        if !picker.waitForExistence(timeout: 2) {
            for _ in 0..<6 { app.swipeUp(); if picker.exists { break } }
        }
        guard picker.exists else {
            XCTFail("industry picker not reachable — US 관할은 업종 확인 없이는 저장할 수 없다")
            return
        }
        picker.tap()
        for label in ["일반산업", "General Industry"] {
            let option = app.buttons[label].firstMatch
            if option.waitForExistence(timeout: 2) { option.tap(); return }
        }
        XCTFail("industry option not found in picker")
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

    /// 화면 밖 행은 lazy List/Form 이 렌더하지 않는다 — 위아래로 훑어 찾는다. WO LEGAL-3A: US 관할을
    /// 고르면 업종 섹션이 추가로 렌더돼 그 아래 요소들이 더 밀려날 수 있다 — 이후 요소를 찾을 때는
    /// 존재를 가정하지 말고 이 헬퍼로 찾는다(RiskAssessmentPathUITests 의 scrollTo 와 같은 패턴).
    /// `exists` 만으로는 부족하다 — 프레임 일부만 화면에 걸쳐도 트리엔 존재해 `waitForExistence` 는
    /// 통과하지만 tap 좌표가 창 밖으로 나가 아무 반응이 없을 수 있다(재현: 화면 하단 852pt 창에서
    /// y 832–876 버튼). `isHittable` 까지 함께 확인해 실제로 탭 가능한 상태까지 스크롤한다.
    @discardableResult
    func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, swipes: Int = 12) -> Bool {
        if element.waitForExistence(timeout: 2), element.isHittable { return true }
        for _ in 0..<swipes {
            app.swipeUp()
            if element.exists && element.isHittable { return true }
        }
        for _ in 0..<swipes {
            app.swipeDown()
            if element.exists && element.isHittable { return true }
        }
        return element.exists && element.isHittable
    }
}
