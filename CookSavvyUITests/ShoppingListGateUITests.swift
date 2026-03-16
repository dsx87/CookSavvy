import XCTest

final class ShoppingListGateUITests: FreeUserUITest {
    func testPremiumGate() {
        app.navigateToRecipeDetail(ingredients: ["Garlic"], recipeTitle: "Test Garlic Pasta")

        app.tapElement(withIdentifier: AccessibilityID.RecipeDetails.addToShoppingList)

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Upgrade.premiumPlan], timeout: 5))
        XCTAssertFalse(app.otherElements[AccessibilityID.ShoppingList.emptyState].exists)
    }
}
