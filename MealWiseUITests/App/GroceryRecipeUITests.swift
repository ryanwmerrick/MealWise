import XCTest

final class GroceryRecipeUITests: XCTestCase {
    @MainActor
    func testEveryMealOpensAndGroceryCheckSurvivesRelaunch() {
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
        let checkbox = app.buttons.matching(identifier: "grocery.check").firstMatch
        XCTAssertTrue(checkbox.waitForExistence(timeout: 5))
        checkbox.tap()
        XCTAssertTrue(checkbox.isSelected)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Phase 4 groceries"
        capture.lifetime = .keepAlways
        add(capture)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Groceries"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "grocery.check").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(identifier: "grocery.check").firstMatch.isSelected)
    }
}
