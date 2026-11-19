import XCTest

final class PantryUITests: XCTestCase {
    @MainActor
    func testCustomPantryItemUseAndOptionalReview() {
        let app = XCUIApplication(); buildPlan(app)
        app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(app.staticTexts["Your pantry is empty"].waitForExistence(timeout: 5))
        app.buttons["Add pantry item"].tap()
        app.buttons["pantry.ingredient"].tap()
        app.buttons["Other ingredient"].tap()
        let name = app.textFields["pantry.customName"]
        name.tap()
        name.typeText("Homemade rolls")
        let quantity = app.textFields["pantry.quantity"]
        quantity.tap()
        quantity.typeText("4")
        reveal(app.buttons["Save pantry item"], in: app)
        app.buttons["Save pantry item"].tap()
        let item = app.buttons.matching(identifier: "pantry.item").firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        XCTAssertTrue(item.label.contains("4 items left"))
        item.tap()
        app.textFields["Amount used"].tap()
        app.textFields["Amount used"].typeText("1")
        app.buttons["Use some"].tap()
        XCTAssertTrue(app.navigationBars["Pantry"].waitForExistence(timeout: 5))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "3 items left"), object: item)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        app.buttons["pantry.review"].tap()
        let reviewCard = app.descendants(matching: .any)["pantry.review.card"]
        XCTAssertTrue(reviewCard.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(reviewCard.frame.height, app.frame.height * 0.55)
        let reviewCapture = XCTAttachment(screenshot: app.screenshot())
        reviewCapture.name = "Full-screen Pantry review"
        reviewCapture.lifetime = .keepAlways
        add(reviewCapture)
        reviewCard.swipeLeft()
        XCTAssertTrue(app.staticTexts["All items reviewed"].waitForExistence(timeout: 5))
        app.buttons["Undo last choice"].tap()
        reviewCard.swipeRight()
        XCTAssertTrue(app.staticTexts["All items reviewed"].waitForExistence(timeout: 5))
        app.buttons["Save Review"].tap()
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        app.buttons["pantry.review"].tap()
        app.buttons["Out of it"].tap()
        app.buttons["Save Review"].tap()
        XCTAssertTrue(app.staticTexts["Your pantry is empty"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTwoWeekLoopSurvivesRelaunch() {
        let app = XCUIApplication(); buildPlan(app)
        app.tabBars.buttons["Groceries"].tap(); app.buttons["grocery.start"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "shopping.check").firstMatch.waitForExistence(timeout: 10))
        var visited = Set<String>()
        for _ in 0..<30 {
            for button in app.buttons.matching(identifier: "shopping.check").allElementsBoundByIndex where button.isHittable && !visited.contains(button.label) {
                visited.insert(button.label); button.tap()
            }
            if app.staticTexts["shopping.itemsLeft"].label == "0 items left" { break }
            app.swipeUp()
        }
        XCTAssertEqual(app.staticTexts["shopping.itemsLeft"].label, "0 items left")
        app.buttons["Finish trip"].tap(); app.buttons["Record purchased items"].tap()
        XCTAssertTrue(app.staticTexts["Trip summary"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "pantry.item").firstMatch.waitForExistence(timeout: 5))
        let pantryCapture = XCTAttachment(screenshot: app.screenshot())
        pantryCapture.name = "Pantry inventory grid"
        pantryCapture.lifetime = .keepAlways
        add(pantryCapture)
        app.tabBars.buttons["Today"].tap(); app.buttons.matching(identifier: "today.meal").firstMatch.tap()
        reveal(app.buttons["Mark as cooked"], in: app)
        app.buttons["Mark as cooked"].tap(); app.buttons["Confirm cooked"].tap()
        XCTAssertTrue(app.buttons["Close cooking"].waitForNonExistence(timeout: 10))
        let rating = app.buttons["rating.liked"]
        reveal(rating, in: app); rating.tap()
        XCTAssertTrue(app.staticTexts["rating.saved"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Week"].tap()
        app.buttons["Plan actions"].tap()
        app.buttons["Plan next week"].tap()
        app.buttons["Finish this week"].tap()
        XCTAssertTrue(app.navigationBars["Plan next week"].waitForExistence(timeout: 10))
        app.terminate(); app.launch(); app.tabBars.buttons["Pantry"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "pantry.item").firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Week"].tap()
        app.buttons["Plan actions"].tap()
        app.buttons["Plan next week"].tap()
        app.buttons["Favorites and next-plan pins"].tap()
        let pin = app.buttons["Pin into next plan"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        let pinnedTitle = app.staticTexts["favorite.recipe"].label
        pin.tap()
        let savePin = app.buttons["Save next-plan pin"]
        reveal(savePin, in: app); savePin.tap()
        XCTAssertTrue(savePin.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove pin"].exists)
        app.navigationBars["Favorites"].buttons["Done"].tap()
        reveal(app.buttons["Review next-week setup"], in: app); app.buttons["Review next-week setup"].tap()
        continueSetup(app, count: 11)
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.buttons["Accept new plan"].waitForExistence(timeout: 30))
        app.buttons["Review stock used"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "next.stock.credit").firstMatch.waitForExistence(timeout: 5))
        let reviewMeals = app.buttons["Review dates and meals"]
        reveal(reviewMeals, in: app); reviewMeals.tap()
        let nextMeal = app.staticTexts.matching(identifier: "setup.preview.recipe").firstMatch
        XCTAssertTrue(nextMeal.waitForExistence(timeout: 5))
        XCTAssertEqual(nextMeal.label, pinnedTitle)
        reviewMeals.tap()
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Phase 9 next-week stock comparison"; capture.lifetime = .keepAlways; add(capture)
        reveal(app.buttons["Accept new plan"], in: app); app.buttons["Accept new plan"].tap()
        XCTAssertTrue(app.buttons["Accept new plan"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Week"].wait(for: \.isHittable, toEqual: true, timeout: 10))
        XCTAssertTrue(app.buttons["week.budget"].waitForExistence(timeout: 10))
        app.buttons["week.settings"].tap()
        XCTAssertTrue(app.navigationBars["Plan settings"].waitForExistence(timeout: 5))
        let history = app.buttons["Cycle history"]
        reveal(history, in: app)
        history.tap()
        app.buttons.matching(identifier: "history.cycle").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Week summary"].waitForExistence(timeout: 5))
        app.buttons["Shopping receipts"].tap()
        let receipt = app.buttons.matching(identifier: "shopping.history").firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 5)); receipt.tap()
        XCTAssertTrue(app.staticTexts["Trip summary"].waitForExistence(timeout: 5))
    }

    @MainActor private func buildPlan(_ app: XCUIApplication) {
        launchFresh(app); app.buttons["welcome.start"].tap()
        continueSetup(app, count: 11)
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
