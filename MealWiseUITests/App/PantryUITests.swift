import XCTest

final class PantryUITests: XCTestCase {
    @MainActor
    func testPantryOffersWrapUpAndInventoryEditor() {
        let app = XCUIApplication(); buildPlan(app)
        app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(app.buttons["Wrap up this cycle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add pantry item"].exists)
    }

    @MainActor
    func testTwoWeekLoopSurvivesRelaunch() {
        let app = XCUIApplication(); buildPlan(app)
        app.tabBars.buttons["Groceries"].tap(); app.buttons["Start shopping"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "shopping.check").firstMatch.waitForExistence(timeout: 10))
        var visited = Set<String>()
        for _ in 0..<30 {
            for button in app.buttons.matching(identifier: "shopping.check").allElementsBoundByIndex where button.isHittable && !visited.contains(button.label) {
                visited.insert(button.label); button.tap()
            }
            if app.buttons["Finish trip"].exists && app.buttons["Finish trip"].isHittable { break }
            app.swipeUp()
        }
        app.buttons["Finish trip"].tap(); app.buttons["Record purchased items"].tap()
        XCTAssertTrue(app.staticTexts["Trip summary"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Today"].tap(); app.buttons.matching(identifier: "today.meal").firstMatch.tap()
        reveal(app.buttons["Mark as cooked"], in: app)
        app.buttons["Mark as cooked"].tap(); app.buttons["Confirm cooked"].tap()
        XCTAssertTrue(app.buttons["Close cooking"].waitForNonExistence(timeout: 10))
        app.tabBars.buttons["Pantry"].tap(); app.buttons["Wrap up this cycle"].tap()
        let available = app.switches.matching(identifier: "wrap.available").firstMatch
        reveal(available, in: app)
        // Native switches expose the full label row; tap the trailing control.
        available.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(available.value as? String, "1", "Carryover must be explicitly checked before closing the cycle")
        let checked = XCTAttachment(screenshot: app.screenshot()); checked.name = "Checked carryover source"; checked.lifetime = .keepAlways; add(checked)
        app.buttons["Confirm carryover"].tap(); app.buttons["Finish cycle"].tap()
        XCTAssertTrue(app.buttons["Plan next week"].waitForExistence(timeout: 10))
        app.terminate(); app.launch(); app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(app.buttons["Plan next week"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(identifier: "pantry.item").firstMatch.exists)
        app.buttons["Plan next week"].tap(); app.buttons["Review next-week setup"].tap()
        for _ in 0..<7 { app.buttons["setup.continue"].tap() }
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.buttons["Accept new plan"].waitForExistence(timeout: 30))
        app.buttons["Review stock used"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "next.stock.credit").firstMatch.waitForExistence(timeout: 5))
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Phase 9 next-week stock comparison"; capture.lifetime = .keepAlways; add(capture)
        reveal(app.buttons["Accept new plan"], in: app); app.buttons["Accept new plan"].tap()
        XCTAssertTrue(app.buttons["Accept new plan"].waitForNonExistence(timeout: 10))
        app.tabBars.buttons["Week"].tap()
        XCTAssertTrue(app.buttons["week.budget"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Pantry"].tap(); app.buttons["Cycle history"].tap()
        app.buttons.matching(identifier: "history.cycle").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Cycle summary"].waitForExistence(timeout: 5))
        app.buttons["Shopping receipts"].tap()
        let receipt = app.buttons.matching(identifier: "shopping.history").firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 5)); receipt.tap()
        XCTAssertTrue(app.staticTexts["Trip summary"].waitForExistence(timeout: 5))
    }

    @MainActor private func buildPlan(_ app: XCUIApplication) {
        launchFresh(app); app.buttons["welcome.start"].tap()
        for _ in 0..<7 { app.buttons["setup.continue"].tap() }
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 30))
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<35 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists); XCTAssertTrue(element.isHittable)
    }
}
