import XCTest

final class GroceryRecipeUITests: XCTestCase {
    @MainActor
    func testEveryMealOpensAndGroceriesAreReadOnly() {
        let app = XCUIApplication()
        launchFresh(app)
        app.buttons["welcome.start"].tap()
        continueSetup(app, count: 11)
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 30))
        var opened: Set<String> = []
        for _ in 0..<5 {
            var next: XCUIElement?
            for _ in 0..<6 {
                next = app.buttons.matching(identifier: "week.meal").allElementsBoundByIndex.first {
                    $0.isHittable && !opened.contains($0.label)
                }
                if next != nil { break }
                app.swipeUp()
            }
            guard let row = next else { XCTFail("Every scheduled meal should be reachable"); return }
            opened.insert(row.label)
            row.tap()
            XCTAssertTrue(app.staticTexts["Ingredients for this meal"].waitForExistence(timeout: 5))
            if opened.count == 1 {
                let capture = XCTAttachment(screenshot: app.screenshot())
                capture.name = "Phase 4 recipe"
                capture.lifetime = .keepAlways
                add(capture)
            }
            app.navigationBars.buttons.firstMatch.tap()
        }
        app.tabBars.buttons["Groceries"].tap()
        XCTAssertTrue(app.staticTexts["Estimated Cost"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["grocery.start"].exists)
        XCTAssertTrue(app.buttons["grocery.history"].exists)
        XCTAssertFalse(app.buttons.matching(identifier: "grocery.check").firstMatch.exists)
        XCTAssertFalse(app.buttons.matching(identifier: "shopping.check").firstMatch.exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Phase 4 groceries"
        capture.lifetime = .keepAlways
        add(capture)

        XCTAssertTrue(app.staticTexts["Your List"].exists)
        XCTAssertFalse(app.staticTexts["Uses actual prices when entered and sample prices for the rest."].exists)
        app.buttons["grocery.add"].tap()
        app.textFields["Ingredient"].tap()
        app.textFields["Ingredient"].typeText("Fresh basil")
        app.textFields["Quantity (optional)"].tap()
        app.textFields["Quantity (optional)"].typeText("1 bunch")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Fresh basil")).firstMatch.waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Groceries"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Fresh basil")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["grocery.start"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "shopping.manualCheck").matching(NSPredicate(format: "label CONTAINS %@", "Fresh basil")).firstMatch.waitForExistence(timeout: 5))
    }
}
