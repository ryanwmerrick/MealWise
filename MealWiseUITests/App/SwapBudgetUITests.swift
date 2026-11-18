import XCTest

final class SwapBudgetUITests: XCTestCase {
    @MainActor
    func testTargetedSwapAndBudgetCancelAccept() {
        let app = XCUIApplication()
        launchFresh(app)
        app.buttons["welcome.start"].tap()
        for _ in 0..<7 { app.buttons["setup.continue"].tap() }
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 30))
        let original = app.buttons.matching(identifier: "week.meal").firstMatch.label
        app.buttons.matching(identifier: "week.swap").firstMatch.tap()
        let option = app.buttons.matching(identifier: "swap.option").firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        app.buttons["Confirm swap"].tap()
        XCTAssertTrue(app.buttons["Confirm swap"].waitForNonExistence(timeout: 5))
        XCTAssertNotEqual(app.buttons.matching(identifier: "week.meal").firstMatch.label, original)
        let budgetBefore = app.buttons["week.budget"].label
        app.buttons["week.budget"].tap()
        reveal(app.buttons["Adjust budget"], in: app)
        app.buttons["Adjust budget"].tap()
        app.buttons["adjust.preset.40"].tap()
        app.buttons["Preview budget"].tap()
        reveal(app.buttons["Keep current plan"], in: app)
        app.buttons["Keep current plan"].tap()
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["week.budget"].label, budgetBefore)
        app.buttons["week.budget"].tap()
        reveal(app.buttons["Adjust budget"], in: app)
        app.buttons["Adjust budget"].tap()
        app.buttons["adjust.preset.55"].tap()
        app.buttons["Preview budget"].tap()
        reveal(app.buttons["Accept change"], in: app)
        app.buttons["Accept change"].tap()
        XCTAssertTrue(app.buttons["Accept change"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["week.budget"].label.contains("55.00"))
    }

    @MainActor
    func testRemainderSuggestionShowsCartImpact() {
        let app = XCUIApplication()
        launchFresh(app)
        app.buttons["welcome.start"].tap()
        for _ in 0..<7 { app.buttons["setup.continue"].tap() }
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 30))
        app.buttons["week.map"].tap()
        let onion = app.buttons.matching(identifier: "ingredient.row").matching(NSPredicate(format: "label CONTAINS %@", "Yellow onion")).firstMatch
        reveal(onion, in: app)
        onion.tap()
        let suggestions = app.buttons["Find a meal using this remainder"]
        reveal(suggestions, in: app)
        suggestions.tap()
        let option = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "New checkout:")).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 15))
        option.tap()
        XCTAssertTrue(app.staticTexts["Before and after"].waitForExistence(timeout: 10))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Phase 6 remainder cart preview"
        capture.lifetime = .keepAlways
        add(capture)
        reveal(app.buttons["Keep current plan"], in: app)
        app.buttons["Keep current plan"].tap()
        XCTAssertTrue(app.staticTexts["Use a remainder"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
    }
}
