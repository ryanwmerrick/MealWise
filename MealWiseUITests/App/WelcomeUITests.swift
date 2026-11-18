import XCTest

final class WelcomeUITests: XCTestCase {
    @MainActor
    func testWelcomeAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL", "-AppleInterfaceStyle", "Light"]
        launchFresh(app)
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .dynamicType, .textClipped])
    }

    @MainActor
    func testWelcomeStartsSetupAndBackReturns() {
        let app = XCUIApplication()
        launchFresh(app)
        let start = app.buttons["welcome.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.staticTexts["What is your goal?"].waitForExistence(timeout: 5))
        app.buttons["Go back"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
    }

    @MainActor
    func testWelcomeSupportsLargeTextAndDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"]
        launchFresh(app)
        let start = app.buttons["welcome.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(app.staticTexts["What is your goal?"].waitForExistence(timeout: 5))
    }
}

extension XCTestCase {
    @MainActor
    func continueSetup(_ app: XCUIApplication, count: Int) {
        for _ in 0..<count { app.buttons["setup.continue"].tap() }
    }

    @MainActor
    func enterSetupBudget(_ amount: String, in app: XCUIApplication) {
        let field = app.textFields["setup.budget"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        field.typeText(amount)
        XCTAssertEqual(field.value as? String, amount)
        app.buttons["Done"].tap()
    }

    @MainActor
    func launchFresh(_ app: XCUIApplication) {
        app.launchEnvironment["MEALWISE_UI_TEST_STORE"] = UUID().uuidString
        app.launch()
    }
}
