import XCTest

final class IngredientMapUITests: XCTestCase {
    @MainActor
    func testWeekMapIngredientAndRecipe() {
        let app = XCUIApplication()
        launchFresh(app)
        app.buttons["welcome.start"].tap()
        for _ in 0..<7 { app.buttons["setup.continue"].tap() }
        app.buttons["setup.build"].tap()
        XCTAssertTrue(app.staticTexts["Your week"].waitForExistence(timeout: 30))
        app.buttons["week.map"].tap()
        XCTAssertTrue(app.staticTexts["Ingredient map"].waitForExistence(timeout: 5))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Phase 5 ingredient map"
        capture.lifetime = .keepAlways
        add(capture)
        app.buttons.matching(identifier: "ingredient.row").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Planned use"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "allocation.meal").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ingredients for this meal"].waitForExistence(timeout: 5))
    }
}
