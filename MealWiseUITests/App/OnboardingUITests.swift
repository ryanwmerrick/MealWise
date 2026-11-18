import XCTest

final class OnboardingUITests: XCTestCase {
    @MainActor
    func testOnboardingUsesSavedChoicesAndScrollableBudget() {
        let app = XCUIApplication()
        launchFresh(app)
        let start = app.buttons["welcome.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertEqual(start.label, "Get Started")
        XCTAssertFalse(app.buttons["welcome.savedData"].exists)
        app.buttons["welcome.signIn"].tap()
        XCTAssertTrue(app.alerts["Sign in"].exists)
        app.alerts.buttons["OK"].tap()
        capture(app, "Welcome")
        start.tap()
        app.buttons["Save money"].tap()
        app.buttons["Eat healthier"].tap()
        continueSetup(app, count: 2)
        capture(app, "Weekday and meal selection")
        continueSetup(app, count: 5)
        app.buttons["Walmart"].tap()
        capture(app, "Store selection")
        continueSetup(app, count: 1)
        XCTAssertTrue(app.staticTexts["What are your dietary preferences?"].exists)
        continueSetup(app, count: 1)
        XCTAssertTrue(app.staticTexts["Do you have any food allergies?"].exists)
        continueSetup(app, count: 1)
        let budget = app.textFields["setup.budget"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5))
        let scale = app.descendants(matching: .any)["setup.budget.scale"].firstMatch
        XCTAssertTrue(scale.exists)
        scale.swipeLeft(velocity: .slow)
        let amount = Int(budget.value as? String ?? "")
        XCTAssertNotNil(amount)
        XCTAssertGreaterThan(amount ?? 0, 70)
        XCTAssertEqual((amount ?? 1) % 5, 0)
        let breakdown = app.staticTexts["setup.budget.perServing"]
        XCTAssertTrue(breakdown.exists)
        XCTAssertTrue(breakdown.label.contains("per adult portion"))
        capture(app, "Weekly budget")
        continueSetup(app, count: 1)
        XCTAssertTrue(app.staticTexts["Walmart"].exists)
        XCTAssertTrue(app.buttons["setup.build"].exists)
    }

    @MainActor
    func testFailedBuildShowsPinnedTopBanner() {
        let app = XCUIApplication()
        launchFresh(app)
        app.buttons["welcome.start"].tap()
        continueSetup(app, count: 10)
        let budget = app.textFields["setup.budget"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5))
        budget.tap()
        budget.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        budget.typeText("1")
        XCTAssertEqual(budget.value as? String, "1")
        app.buttons["Done"].tap()
        continueSetup(app, count: 1)
        app.buttons["setup.build"].tap()
        let banner = app.descendants(matching: .any)["setup.error.banner"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 30))
        XCTAssertTrue(banner.isHittable)
        XCTAssertLessThan(banner.frame.maxY, app.frame.midY)
        app.swipeUp()
        XCTAssertTrue(banner.isHittable)
        XCTAssertLessThan(banner.frame.maxY, app.frame.midY)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Pinned plan failure banner"
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor
    func testInvalidBudgetAndSameSessionReentry() {
        let app = XCUIApplication()
        launchFresh(app)
        app.buttons["welcome.start"].tap()
        continueSetup(app, count: 10)
        let budget = app.textFields["setup.budget"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5))
        budget.tap()
        budget.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "0.00")
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["setup.continue"].isEnabled)
        enterSetupBudget("55", in: app)
        XCTAssertTrue(app.buttons["setup.continue"].isEnabled)
        for _ in 0..<11 { app.buttons["Go back"].tap() }
        app.buttons["welcome.start"].tap()
        continueSetup(app, count: 10)
        XCTAssertEqual(budget.value as? String, "55")
    }

    @MainActor
    func testSetupEditBuildAndRelaunch() {
        let app = XCUIApplication()
        launchFresh(app)
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 10))
        app.buttons["welcome.start"].tap()
        continueSetup(app, count: 11)
        app.buttons["summary.edit.budget"].tap()
        enterSetupBudget("55", in: app)
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
    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
