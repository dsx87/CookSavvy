import XCTest

final class RecipeDetailsUITests: FreeUserUITest {
    func testDetailContent() {
        app.navigateToRecipeDetail(ingredients: ["Garlic", "Pasta"], recipeTitle: "Test Garlic Pasta")

        XCTAssertTrue(app.waitForElement(app.staticTexts[AccessibilityID.RecipeDetails.title], timeout: 5))
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.RecipeDetails.ingredientsSection], timeout: 5))
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.RecipeDetails.stepsSection], timeout: 5))
        XCTAssertTrue(app.waitForElement(app.buttons[AccessibilityID.RecipeDetails.startCookingButton], timeout: 5))
    }

    func testBookmarkToggle() {
        app.navigateToRecipeDetail(ingredients: ["Salmon"], recipeTitle: "Test Salmon Bowl")

        app.tapElement(withIdentifier: AccessibilityID.RecipeDetails.bookmarkButton)
        app.goBack()
        app.buttons["Edit"].tap()

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.savedSection], timeout: 5))
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.recipe("Test Salmon Bowl")], timeout: 5))
    }

    func testAddMissingGatedForFree() {
        app.navigateToRecipeDetail(ingredients: ["Garlic"], recipeTitle: "Test Garlic Pasta")

        app.tapElement(withIdentifier: AccessibilityID.RecipeDetails.addToShoppingList)

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Upgrade.premiumPlan], timeout: 5))
    }

    func testStartCookingNav() {
        app.navigateToRecipeDetail(ingredients: ["Garlic", "Pasta"], recipeTitle: "Test Garlic Pasta")

        app.tapElement(withIdentifier: AccessibilityID.RecipeDetails.startCookingButton)

        XCTAssertTrue(app.waitForElement(app.staticTexts[AccessibilityID.CookMode.stepText], timeout: 5))
    }
}
