import XCTest

final class DiscoverResultsUITests: FreeUserUITest {
    func testResultsDisplay() {
        app.selectIngredient("Garlic")
        app.selectIngredient("Pasta")
        app.tapFindRecipes()

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.bestMatch], timeout: 10))
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.moreRecipes], timeout: 10))
    }

    func testMoodFilter() {
        app.selectIngredient("Garlic")
        app.tapFindRecipes()

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.bestMatch], timeout: 10))
        app.tapElement(withIdentifier: AccessibilityID.Discover.mood("bold"))

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.recipe("Test Veggie Stir-Fry")], timeout: 10))
    }

    func testUseItAllToggle() {
        app.selectIngredient("Garlic")
        app.selectIngredient("Pasta")
        app.tapFindRecipes()

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.moreRecipes], timeout: 10))
        app.tapElement(withIdentifier: AccessibilityID.Discover.useItAllToggle)

        XCTAssertTrue(app.waitForDisappearance(of: app.otherElements[AccessibilityID.Discover.moreRecipes], timeout: 5))
    }

    func testSuggestedSection() {
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.suggestedSection], timeout: 10))
    }

    func testEditIngredientsFromResults() {
        app.selectIngredient("Garlic")
        app.selectIngredient("Pasta")
        app.tapFindRecipes()

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.bestMatch], timeout: 10))
        app.buttons["Edit"].tap()

        XCTAssertTrue(app.waitForElement(app.textFields[AccessibilityID.Discover.searchField], timeout: 5))
    }
}
