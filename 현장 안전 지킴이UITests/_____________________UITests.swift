import XCTest

final class SafetyWalkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        // UI test cases will be added in Phase 2.
    }
}
