import XCTest

final class RepeatUseUITests: XCTestCase {
    @MainActor func testLocalFavoritesAndWeeklyNutrition() {
        let app = XCUIApplication(); launchFresh(app)
        app.buttons["welcome.start"].tap()
        continueSetup(app, count: 11)
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.buttons["week.settings"].waitForExistence(timeout: 30))
        app.buttons["week.settings"].tap()
        reveal(app.buttons["Favorites"], in: app); app.buttons["Favorites"].tap()
        XCTAssertTrue(app.staticTexts["Your saved recipes"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(app.buttons["Weekly nutrition"], in: app); app.buttons["Weekly nutrition"].tap()
        XCTAssertTrue(app.staticTexts["Planned meals: 5"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["nutrition.vegetable"].exists)
    }
    @MainActor func testRepeatUseSupportsLargeText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"]
        launchFresh(app); app.buttons["welcome.start"].tap()
        continueSetup(app, count: 11)
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.buttons["week.settings"].waitForExistence(timeout: 30)); app.buttons["week.settings"].tap()
        for title in ["Favorites", "Weekly nutrition"] {
            reveal(app.buttons[title], in: app); app.buttons[title].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Phase 10 large text " + title; capture.lifetime = .keepAlways; add(capture)
            try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .dynamicType, .textClipped])
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }
    @MainActor func testEraseLocalDataClearsDraftAfterRelaunch() {
        let app = XCUIApplication()
        launchFresh(app)
        app.buttons["welcome.start"].tap()
        continueSetup(app, count: 10)
        enterSetupBudget("55", in: app)
        continueSetup(app, count: 1)
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.buttons["week.settings"].waitForExistence(timeout: 30))
        app.buttons["week.settings"].tap()
        let erase = app.buttons["Erase all local data"]
        reveal(erase, in: app); erase.tap()
        app.buttons["Erase local data"].tap()
        XCTAssertTrue(erase.waitForNonExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["welcome.start"].waitForExistence(timeout: 5))
        app.buttons["welcome.start"].tap()
        continueSetup(app, count: 10)
        XCTAssertEqual(app.textFields["setup.budget"].value as? String, "70")
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<18 { if element.exists && element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.exists)
    }
}
