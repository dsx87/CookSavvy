import XCTest

final class CookModeUITests: FreeUserUITest {
    func testStepNavigation() {
        openCookMode()

        XCTAssertTrue(app.waitForElement(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Boil pasta'")).element,
            timeout: 5
        ))

        app.tapElement(withIdentifier: AccessibilityID.CookMode.nextButton)
        XCTAssertTrue(app.waitForElement(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sauté minced garlic'")).element,
            timeout: 5
        ))

        app.tapElement(withIdentifier: AccessibilityID.CookMode.previousButton)
        XCTAssertTrue(app.waitForElement(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Boil pasta'")).element,
            timeout: 5
        ))
    }

    func testCompletion() {
        openCookMode()

        for _ in 0..<4 {
            app.tapElement(withIdentifier: AccessibilityID.CookMode.doneButton)
        }

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.CookMode.feedbackOverlay], timeout: 5))
        app.tapElement(withIdentifier: AccessibilityID.CookMode.skipRating)

        XCTAssertTrue(app.waitForElement(app.buttons[AccessibilityID.RecipeDetails.startCookingButton], timeout: 5))
    }

    func testDismiss() {
        openCookMode()

        app.tapElement(withIdentifier: AccessibilityID.CookMode.closeButton)

        XCTAssertTrue(app.waitForElement(app.staticTexts[AccessibilityID.RecipeDetails.title], timeout: 5))
    }

    private func openCookMode() {
        app.navigateToRecipeDetail(ingredients: ["Garlic", "Pasta"], recipeTitle: "Test Garlic Pasta")
        app.tapElement(withIdentifier: AccessibilityID.RecipeDetails.startCookingButton)
        XCTAssertTrue(app.waitForElement(app.staticTexts[AccessibilityID.CookMode.stepText], timeout: 5))
    }
}
