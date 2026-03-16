import XCTest

final class RecipeDetailsPremiumUITests: PremiumUserUITest {
    func testAddMissingToShoppingList() {
        app.navigateToRecipeDetail(ingredients: ["Garlic"], recipeTitle: "Test Garlic Pasta")

        XCTAssertTrue(app.waitForElement(app.staticTexts[AccessibilityID.RecipeDetails.title], timeout: 5))
        app.swipeUp()
        app.tapElement(withIdentifier: AccessibilityID.RecipeDetails.addToShoppingList)

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.ShoppingList.item("Pasta")], timeout: 5))
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.ShoppingList.item("Olive Oil")], timeout: 5))
    }
}
