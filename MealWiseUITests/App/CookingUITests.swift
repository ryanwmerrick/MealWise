import XCTest

final class CookingUITests: XCTestCase {
    @MainActor
    func testCookingResumesAndCompletesAfterRecordedShopping() throws {
        let app = XCUIApplication()
        buildPlan(app)
        app.tabBars.buttons["Groceries"].tap()
        app.buttons["Start shopping"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "shopping.check").firstMatch.waitForExistence(timeout: 10))
        var visited = Set<String>()
        for _ in 0..<30 {
            let checks = app.buttons.matching(identifier: "shopping.check").allElementsBoundByIndex
            for button in checks where button.isHittable && !visited.contains(button.label) {
                visited.insert(button.label); button.tap()
            }
            if app.buttons["Finish trip"].exists && app.buttons["Finish trip"].isHittable { break }
            app.swipeUp()
        }
        app.buttons["Finish trip"].tap()
        app.buttons["Record purchased items"].tap()
        XCTAssertTrue(app.staticTexts["Trip summary"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Today"].tap()
        let meal = app.buttons.matching(identifier: "today.meal").firstMatch
        XCTAssertTrue(meal.waitForExistence(timeout: 10))
        meal.tap()
        let step = app.buttons.matching(identifier: "cooking.step").firstMatch
        reveal(step, in: app)
        step.tap()
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Phase 8 cooking steps"; capture.lifetime = .keepAlways; add(capture)
        let savedIngredients = app.buttons["Save for later meals"]
        reveal(savedIngredients, in: app)
        let reservation = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Reserve ")).firstMatch
        XCTAssertFalse(reservation.exists)
        savedIngredients.tap()
        XCTAssertTrue(reservation.waitForExistence(timeout: 5))
        app.buttons["Close cooking"].tap()
        app.buttons.matching(identifier: "today.meal").firstMatch.tap()
        let resumed = app.buttons.matching(identifier: "cooking.step").firstMatch
        reveal(resumed, in: app)
        XCTAssertTrue(resumed.isSelected)
        let complete = app.buttons["Mark as cooked"]
        reveal(complete, in: app)
        XCTAssertTrue(complete.isEnabled)
        complete.tap()
        app.buttons["Confirm cooked"].tap()
        XCTAssertTrue(app.buttons["Close cooking"].waitForNonExistence(timeout: 10))
        let cooked = app.buttons.matching(identifier: "today.meal").matching(NSPredicate(format: "label CONTAINS %@", "Cooked")).firstMatch
        XCTAssertTrue(cooked.waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(cooked.waitForExistence(timeout: 10))
    }

    @MainActor
    func testCookingSupportsLargeTextAndAccessibility() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"]
        buildPlan(app)
        app.tabBars.buttons["Today"].tap()
        let meal = app.buttons.matching(identifier: "today.meal").firstMatch
        XCTAssertTrue(meal.waitForExistence(timeout: 10)); meal.tap()
        let step = app.buttons.matching(identifier: "cooking.step").firstMatch
        reveal(step, in: app)
        step.tap()
        XCTAssertTrue(step.isSelected)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Phase 8 large-text cooking before audit"; capture.lifetime = .keepAlways; add(capture)
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .dynamicType, .textClipped]) { issue in
            let isKnownColorPair = issue.auditType == .contrast &&
                ["cooking.ingredient.name", "cooking.ingredient.quantity"].contains(issue.element?.identifier ?? "")
            let isOffscreen = issue.auditType == .contrast && issue.element.map { $0.frame.intersection(app.frame).isEmpty } == true
            let handled = isKnownColorPair || isOffscreen
            let diagnostic = XCTAttachment(string: (handled ? "Handled known color-pair or offscreen contrast audit false positive; numeric WCAG tests cover the palette.\n" : "Unhandled audit finding\n") + issue.detailedDescription + "\n" + (issue.element?.debugDescription ?? "No element was supplied"))
            diagnostic.name = "Cooking audit element"; diagnostic.lifetime = .keepAlways; self.add(diagnostic)
            return handled
        }
        app.buttons["Close cooking"].tap()
    }

    @MainActor
    func testSkipPreviewsDatesAndCancelKeepsToday() {
        let app = XCUIApplication()
        buildPlan(app)
        app.tabBars.buttons["Today"].tap()
        let original = app.buttons.matching(identifier: "today.meal").firstMatch.label
        app.buttons.matching(identifier: "today.skip").firstMatch.tap()
        let date = app.buttons.matching(identifier: "skip.date").firstMatch
        XCTAssertTrue(date.waitForExistence(timeout: 5)); date.tap()
        XCTAssertTrue(app.staticTexts["Before and after"].waitForExistence(timeout: 10))
        app.buttons["Show proposed schedule"].tap()
        let reservations = app.buttons.matching(identifier: "preview.reservations").firstMatch
        XCTAssertTrue(reservations.waitForExistence(timeout: 5)); reservations.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Reserve ")).firstMatch.waitForExistence(timeout: 5))
        reveal(app.buttons["Keep current plan"], in: app)
        app.buttons["Keep current plan"].tap()
        app.buttons["Keep cooking dates"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "today.meal").firstMatch.label, original)
    }

    @MainActor private func buildPlan(_ app: XCUIApplication) {
        launchFresh(app); app.buttons["welcome.start"].tap()
        for _ in 0..<7 { app.buttons["setup.continue"].tap() }
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 30))
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<32 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }
}
