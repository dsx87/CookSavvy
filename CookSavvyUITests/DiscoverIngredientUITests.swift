import XCTest

final class DiscoverIngredientUITests: FreeUserUITest {
    func testSearchFilters() {
        let searchField = app.textFields[AccessibilityID.Discover.searchField]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("gar")

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.ingredient("Garlic")], timeout: 5))
        XCTAssertFalse(app.otherElements[AccessibilityID.Discover.ingredient("Chicken Breast")].exists)
    }

    func testCategoryFilter() {
        app.tapElement(withIdentifier: AccessibilityID.Discover.category("veggies"))

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.ingredient("Bell Pepper")], timeout: 5))
        XCTAssertFalse(app.otherElements[AccessibilityID.Discover.ingredient("Chicken Breast")].exists)
    }

    func testSelectionAndRemoval() {
        app.selectIngredient("Garlic")
        XCTAssertTrue(app.buttons[AccessibilityID.Discover.findRecipesButton].waitForExistence(timeout: 5))

        app.selectIngredient("Garlic")

        XCTAssertTrue(app.waitForDisappearance(of: app.buttons[AccessibilityID.Discover.findRecipesButton], timeout: 5))
    }

    func testRecentSection() {
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.savedSection], timeout: 5))

        app.openRecipeResult("Test Garlic Pasta")
        XCTAssertTrue(app.waitForElement(app.staticTexts["Test Garlic Pasta"], timeout: 5))

        app.goBack()

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.recentSection], timeout: 5))
    }

    func testFindRecipesTrigger() {
        app.selectIngredient("Garlic")
        app.selectIngredient("Pasta")
        app.tapFindRecipes()

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.bestMatch], timeout: 10))
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.recipe("Test Garlic Pasta")], timeout: 10))
    }
}
