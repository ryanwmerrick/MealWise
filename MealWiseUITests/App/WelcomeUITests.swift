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
        XCTAssertTrue(app.staticTexts["What can you spend this week?"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["What can you spend this week?"].waitForExistence(timeout: 5))
    }
}

extension XCTestCase {
    @MainActor
    func launchFresh(_ app: XCUIApplication) {
        app.launch()
        if app.buttons["week.settings"].waitForExistence(timeout: 3) {
            app.buttons["week.settings"].tap()
            for _ in 0..<4 {
                if app.buttons["Start over"].exists && app.buttons["Start over"].isHittable { break }
                app.swipeUp()
            }
            app.buttons["Start over"].tap()
            app.buttons["Reset plan"].tap()
        }
    }
}
