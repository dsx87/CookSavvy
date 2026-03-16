import XCTest

final class ShoppingListUITests: PremiumUserUITest {
    func testCRUD() {
        openShoppingList()

        app.tapElement(withIdentifier: AccessibilityID.ShoppingList.checkbox("Pasta"))
        XCTAssertTrue(app.waitForElement(app.buttons[AccessibilityID.ShoppingList.clearDone], timeout: 5))

        app.tapElement(withIdentifier: AccessibilityID.ShoppingList.clearDone)
        XCTAssertTrue(app.waitForDisappearance(of: app.otherElements[AccessibilityID.ShoppingList.item("Pasta")], timeout: 5))
    }

    func testSwipeToDelete() {
        openShoppingList()

        let oliveOil = app.otherElements[AccessibilityID.ShoppingList.item("Olive Oil")]
        XCTAssertTrue(oliveOil.waitForExistence(timeout: 5))
        oliveOil.swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.waitForDisappearance(of: oliveOil, timeout: 5))
        XCTAssertTrue(app.otherElements[AccessibilityID.ShoppingList.item("Parmesan")].exists)
    }

    private func openShoppingList() {
        app.navigateToRecipeDetail(ingredients: ["Garlic"], recipeTitle: "Test Garlic Pasta")
        app.tapElement(withIdentifier: AccessibilityID.RecipeDetails.addToShoppingList)
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.ShoppingList.item("Pasta")], timeout: 5))
    }
}
