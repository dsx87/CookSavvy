import XCTest

final class CookModeUITests: FreeUserUITest {
    func testStepNavigation() {
        openCookMode()

        let firstStep = app.staticTexts[AccessibilityID.CookMode.stepText]
        XCTAssertTrue(firstStep.waitForExistence(timeout: 5))
        XCTAssertTrue(firstStep.label.contains("Boil pasta"))

        app.tapElement(withIdentifier: AccessibilityID.CookMode.nextButton)
        XCTAssertTrue(firstStep.label.contains("Sauté minced garlic"))

        app.tapElement(withIdentifier: AccessibilityID.CookMode.previousButton)
        XCTAssertTrue(firstStep.label.contains("Boil pasta"))
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
