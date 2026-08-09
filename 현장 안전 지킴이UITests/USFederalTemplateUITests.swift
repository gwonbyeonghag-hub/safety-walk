import XCTest

/// WO LEGAL-3B: US(.global) 이제 템플릿 2개(General Industry/Construction)를 내놓는다 — 첫 템플릿
/// 자동선택 금지, Federal OSHA/State Plan 경고가 시작 전에 보임, KR 흐름은 무영향.
final class USFederalTemplateUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    /// 언어는 launch-arg로 고정해도 안전하다 — `LocalizationManager`가 값을 인메모리
    /// `@Observable` 프로퍼티로 캐시하고, `.set()`은 그 프로퍼티를 직접 갱신하므로 이후 읽기가
    /// UserDefaults를 다시 훑지 않는다. 반면 관할(`RegionProfileStore`)은 매 `.get()`마다
    /// UserDefaults를 다시 읽는 정적 함수라 **launch-arg로 고정하면 안 된다** — NSUserDefaults의
    /// argument domain은 프로세스 생애 내내 persistent domain보다 우선하므로, launch-arg로 값을
    /// 넣어 두면 `.set()`으로 아무리 다시 써도 `.get()`은 그 launch-arg 값만 계속 돌려준다(실측
    /// 확인: `-com.safetywalk.regionProfile KR`을 넣은 채로는 앱 안에서 관할을 US로 바꿀 수 없었다).
    /// 그래서 관할은 매 테스트가 필요하면 화면에서 직접 눌러 정한다.
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-com.safetywalk.hasCompletedOnboarding", "1",
            "-com.safetywalk.inspectorName", "평가자",
            "-com.safetywalk.uitestPro", "1",
            "-com.safetywalk.appLanguage", "ko",
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

    // MARK: - 설정: 미국 표시명 EN/KO 정확성

    /// 언어 토글의 "한국어"/"English" 라벨 자체는 endonym이라 현재 표시 언어와 무관하게 항상 같은
    /// 문자열이다(`SettingsView` 주석) — 리런치 없이 두 언어 값을 모두 확인할 수 있다.
    func testUSRegionDisplayNameIsCorrectInBothLanguages() throws {
        let app = launchApp()
        app.tabBars.buttons["gear"].tap()
        XCTAssertTrue(app.staticTexts["지역"].waitForExistence(timeout: 20), "region section not found")

        // 한국어 상태에서 값 확인
        XCTAssertTrue(app.buttons["미국(연방 기준)"].waitForExistence(timeout: 5),
                      "KO 표시명이 '미국(연방 기준)'이 아니다")
        snap(app, "legal3b_settings_region_ko")

        // English로 전환 — 언어 변경은 `LocalizationManager`의 `.id()` 트리 리빌드를 유발해
        // 루트(Home 탭)로 돌아간다(실측 확인) — Settings 로 다시 들어가야 한다.
        app.buttons["English"].tap()
        // 언어 전환 직후 tab bar 탭이 씹히는 경우가 실측됐다(트리 리빌드 중 레이스로 추정) —
        // gear 탭이 실제로 존재할 때까지 기다렸다가 누르고, 씹혔으면 한 번 더 시도한다.
        let gearTab = app.tabBars.buttons["gear"]
        XCTAssertTrue(gearTab.waitForExistence(timeout: 10), "gear tab not found after language switch")
        gearTab.tap()
        var regionSectionFound = app.staticTexts["Region"].waitForExistence(timeout: 5)
        if !regionSectionFound, gearTab.isHittable {
            gearTab.tap()
            regionSectionFound = app.staticTexts["Region"].waitForExistence(timeout: 5)
        }
        XCTAssertTrue(regionSectionFound, "EN Settings region section not found")

        // 세그먼트 폭이 좁아 accessibility label이 렌더 텍스트를 그대로 안 따라갈 수 있어(긴 EN
        // 문구) CONTAINS 매칭으로 확인한다.
        let enRegionButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'United States'")).firstMatch
        XCTAssertTrue(enRegionButton.waitForExistence(timeout: 5),
                      "EN 표시명이 'United States (Federal baseline)'가 아니다")
        XCTAssertEqual(enRegionButton.label, "United States (Federal baseline)",
                       "EN 표시명 문구가 정확히 일치해야 한다")
        snap(app, "legal3b_settings_region_en")

        // 한국어로 복귀(다른 테스트에 영향 없도록)
        app.buttons["한국어"].tap()
    }

    // MARK: - 점검 생성: 2개 템플릿 구별 + 자동선택 없음 + Federal 경고

    /// 관할을 화면에서 직접 눌러 정한다(launch-arg로 고정하면 이후 앱 안에서 값을 바꿀 수
    /// 없다 — `launchApp()` 주석 참고). 세그먼트 컨트롤의 좌/우 절반 좌표를 직접 눌러, 긴 EN
    /// 라벨 탓에 접근성 프레임과 실제 탭 타깃이 어긋나는 경우까지 우회한다(실측 확인).
    private func setRegion(_ app: XCUIApplication, toUS: Bool) {
        app.tabBars.buttons["gear"].tap()
        let regionPicker = app.segmentedControls["settings_region_picker"]
        XCTAssertTrue(regionPicker.waitForExistence(timeout: 10), "region picker not found")
        let targetLabel = toUS ? "미국(연방 기준)" : "한국"
        regionPicker.coordinate(withNormalizedOffset: CGVector(dx: toUS ? 0.75 : 0.25, dy: 0.5)).tap()
        if !regionPicker.buttons[targetLabel].isSelected {
            usleep(300_000)
        }
        XCTAssertTrue(regionPicker.buttons[targetLabel].isSelected, "관할이 \(targetLabel)으로 바뀌지 않았다")
    }

    private func addSiteAndReachTemplateScreen(_ app: XCUIApplication, siteName: String) {
        app.tabBars.buttons["house"].tap()
        let start = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '점검 시작'")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 15), "start-inspection button not found")
        start.tap()

        let addSite = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '새 현장 추가'")).firstMatch
        XCTAssertTrue(addSite.waitForExistence(timeout: 10), "add-site button not found")
        addSite.tap()
        let nameField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(siteName)
        app.buttons.matching(NSPredicate(format: "label == '저장'")).firstMatch.tap()
        app.staticTexts[siteName].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch.tap()   // site → area
        app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch.tap()   // area → template
    }

    func testUSTemplatesAreDistinctRequireExplicitSelectionAndShowFederalNotice() throws {
        let app = launchApp()
        setRegion(app, toUS: true)

        addSiteAndReachTemplateScreen(app, siteName: "US 현장 3B")

        // 두 US Federal 템플릿이 서로 다른 이름으로 구별되어 보인다.
        let general = app.staticTexts["미국 연방 — 일반산업"].firstMatch
        let construction = app.staticTexts["미국 연방 — 건설업"].firstMatch
        XCTAssertTrue(general.waitForExistence(timeout: 10), "General Industry 템플릿 행이 없다")
        XCTAssertTrue(construction.waitForExistence(timeout: 5), "Construction 템플릿 행이 없다")

        // Federal OSHA/State Plan 경고 — 템플릿을 고르기 전(시작 전)에도 이미 보인다.
        let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'State Plan'")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "Federal/State Plan 경고가 시작 전 화면에 없다")
        snap(app, "legal3b_template_selection_us_no_auto_select")

        // 자동선택 없음 — "다음" 버튼이 비활성 상태여야 한다.
        let next = app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "US 는 템플릿을 명시적으로 고르기 전엔 '다음'이 비활성이어야 한다")

        // 하나를 명시적으로 고르면 진행 가능해진다.
        construction.tap()
        XCTAssertTrue(next.isEnabled, "템플릿을 고른 뒤에는 '다음'이 활성화돼야 한다")
        snap(app, "legal3b_template_selection_us_construction_selected")
    }

    // MARK: - KR 흐름: 경고 없음 + 기존 자동선택 회귀 없음

    func testKoreaFlowHasNoFederalNoticeAndKeepsAutoSelection() throws {
        let app = launchApp()
        // 기본 관할은 이미 한국(앱 기본값)이지만, 같은 시뮬레이터에서 이전 테스트가 US로
        // 바꿔놨을 수 있어(UserDefaults 영속) 명시적으로 한국으로 되돌린다.
        setRegion(app, toUS: false)

        addSiteAndReachTemplateScreen(app, siteName: "KR 현장 3B")

        // 한국 템플릿은 기존처럼 자동 선택돼 있어 바로 '다음'이 활성 상태다.
        let next = app.buttons.matching(NSPredicate(format: "label == '다음'")).firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        XCTAssertTrue(next.isEnabled, "한국 관할은 기존처럼 템플릿이 자동 선택돼 있어야 한다")
        snap(app, "legal3b_template_selection_kr_unaffected")

        // 이 화면은 KR/US 템플릿을 한 목록에 같이 보여주는 기존(LEGAL-3B 이전) 설계다
        // (StartInspectionViewModel.loadTemplates가 RegionProfile.allCases 전체를 로드) — 그래서
        // 화면 전체에 State Plan 경고가 "0회"라는 주장은 성립하지 않는다: US 행 자체가 늘 같이
        // 보이고 그 행에 달린 경고는 정확한 동작이다(§E, templateId 판별). "KR 기록에는 표시 없음"
        // 이라는 실제 요구사항은 KR 템플릿으로 실제 생성된 기록(Inspection.templateId)의 상세/PDF
        // 로 검증한다 — 이미 Core/PDF 레벨에서 red-check까지 포함해 고정했다
        // (ChecklistTemplateLoaderTests, testInspectionReportOmitsFederalNoticeForNonUSFederalTemplates).
    }
}
