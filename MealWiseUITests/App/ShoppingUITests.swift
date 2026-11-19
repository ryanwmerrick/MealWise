import XCTest

final class ShoppingUITests: XCTestCase {
    @MainActor
    func testCorrectTappedItemFinishAndRelaunchHistory() {
        let app = XCUIApplication()
        launchFresh(app)
        app.buttons["welcome.start"].tap()
        continueSetup(app, count: 11)
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Groceries"].tap()
        let start = app.buttons["grocery.start"]
        let forecast = app.staticTexts["grocery.estimatedCost"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(forecast.waitForExistence(timeout: 5))
        let originalForecast = forecast.label
        start.tap()
        let edit = app.buttons.matching(identifier: "shopping.edit").firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["shopping.elapsed"].exists)
        app.buttons["shopping.store"].tap()
        app.buttons["ALDI"].tap()
        edit.tap()
        let price = app.buttons["shopping.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 10))
        price.tap()
        let field = app.textFields["shopping.actual"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("99.99")
        app.buttons["Save price"].tap()
        let check = app.buttons.matching(identifier: "shopping.check").firstMatch
        check.tap()
        XCTAssertTrue(check.isSelected)
        app.buttons["Minimize shopping"].tap()
        let changedForecast = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label != %@", originalForecast), object: forecast)
        XCTAssertEqual(XCTWaiter.wait(for: [changedForecast], timeout: 5), .completed)
        let revisedForecast = forecast.label
        app.terminate()
        app.launch()
        app.tabBars.buttons["Groceries"].tap()
        XCTAssertTrue(app.buttons["Resume Shopping"].waitForExistence(timeout: 10))
        XCTAssertEqual(forecast.label, revisedForecast)
        start.tap()
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        XCTAssertTrue(check.isSelected)
        XCTAssertTrue(app.buttons["shopping.store"].label.contains("ALDI"))
        let shoppingCapture = XCTAttachment(screenshot: app.screenshot())
        shoppingCapture.name = "Shopping mode"
        shoppingCapture.lifetime = .keepAlways
        add(shoppingCapture)
        let finish = app.buttons["Finish trip"]
        for _ in 0..<14 {
            if finish.exists && finish.isHittable { break }
            app.swipeUp()
        }
        finish.tap()
        app.buttons["Record purchased items"].tap()
        XCTAssertTrue(app.staticTexts["Trip summary"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["shopping.summary.actual"].label.contains("99.99"))
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "Phase 7 partial overspend summary"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Groceries"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Groceries"].tap()
        XCTAssertTrue(forecast.wait(for: \.label, toEqual: revisedForecast, timeout: 5))
        app.buttons["grocery.history"].tap()
        app.buttons.matching(identifier: "shopping.history").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Trip summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["shopping.summary.actual"].label.contains("99.99"))
    }
}
