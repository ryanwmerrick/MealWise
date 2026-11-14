import XCTest

final class OnboardingUITests: XCTestCase {
    @MainActor
    func testInvalidBudgetAndSameSessionReentry() {
        let app = XCUIApplication()
        launchFresh(app)
        app.buttons["welcome.start"].tap()
        let budget = app.textFields["setup.budget"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5))
        budget.tap()
        budget.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "0.00")
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["setup.continue"].isEnabled)
        app.buttons["budget.preset.55"].tap()
        XCTAssertTrue(app.buttons["setup.continue"].isEnabled)
        app.buttons["Go back"].tap()
        app.buttons["welcome.start"].tap()
        XCTAssertEqual(budget.value as? String, "55")
    }

    @MainActor
    func testSetupEditBuildAndRelaunch() {
        let app = XCUIApplication()
        launchFresh(app)
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 10))
        app.buttons["welcome.start"].tap()
        for _ in 0..<7 { app.buttons["setup.continue"].tap() }
        app.buttons["summary.edit.budget"].tap()
        app.buttons["budget.preset.55"].tap()
        app.buttons["setup.continue"].tap()
        XCTAssertTrue(app.buttons["setup.build"].exists)
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["week.budget"].exists)
        app.swipeUp()
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Week after scrolling"
        capture.lifetime = .keepAlways
        add(capture)
        app.buttons["week.budget"].tap()
        XCTAssertTrue(app.staticTexts["Budget details"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        for tab in ["Groceries", "Today", "Pantry", "Week"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected)
        }
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 10))
        app.buttons["week.settings"].tap()
        XCTAssertTrue(app.staticTexts["Plan settings"].waitForExistence(timeout: 5))
    }
}
