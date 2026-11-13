import XCTest

final class WelcomeUITests: XCTestCase {
    @MainActor
    func testWelcomeAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL", "-AppleInterfaceStyle", "Light"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .dynamicType, .textClipped])
    }

    @MainActor
    func testWelcomeOpensEmptyShellAndTabs() {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["welcome.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.staticTexts["No weekly plan yet"].waitForExistence(timeout: 5))
        for tab in ["Groceries", "Today", "Pantry", "Week"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected)
        }
    }

    @MainActor
    func testWelcomeSupportsLargeTextAndDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"]
        app.launch()
        let start = app.buttons["welcome.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(app.staticTexts["No weekly plan yet"].waitForExistence(timeout: 5))
    }
}
