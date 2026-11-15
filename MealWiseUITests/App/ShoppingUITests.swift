import XCTest

final class ShoppingUITests: XCTestCase {
    @MainActor
    func testCorrectTappedItemFinishAndRelaunchHistory() {
        let app = XCUIApplication()
        launchFresh(app)
        app.buttons["welcome.start"].tap()
        for _ in 0..<7 { app.buttons["setup.continue"].tap() }
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Groceries"].tap()
        let start = app.buttons["Start shopping"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let price = app.buttons.matching(identifier: "shopping.price").firstMatch
        XCTAssertTrue(price.waitForExistence(timeout: 10))
        price.tap()
        let field = app.textFields["shopping.actual"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("99.99")
        app.buttons["Save price"].tap()
        let check = app.buttons.matching(identifier: "shopping.check").firstMatch
        check.tap()
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
        app.buttons["Shopping history"].tap()
        app.buttons.matching(identifier: "shopping.history").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Trip summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["shopping.summary.actual"].label.contains("99.99"))
    }
}
