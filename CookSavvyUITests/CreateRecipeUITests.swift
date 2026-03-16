import XCTest

final class CreateRecipeUITests: FreeUserUITest {
    func testWizardFlowComplete() {
        createRecipe(named: "UI Test Flatbread")

        XCTAssertTrue(app.waitForElement(app.staticTexts["UI Test Flatbread"], timeout: 5))
    }

    func testValidation() {
        openCreateRecipe()

        let nextButton = app.buttons[AccessibilityID.CreateRecipe.nextButton]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        XCTAssertFalse(nextButton.isEnabled)

        let recipeName = app.textFields[AccessibilityID.CreateRecipe.recipeName]
        recipeName.tap()
        recipeName.typeText("Validation Recipe")
        XCTAssertTrue(nextButton.isEnabled)

        nextButton.tap()
        XCTAssertTrue(app.waitForElement(app.firstMatch(for: AccessibilityID.CreateRecipe.ingredient(0)), timeout: 5))
        XCTAssertFalse(nextButton.isEnabled)
    }

    func testCreatedRecipeAppearsInJourney() {
        createRecipe(named: "Journey UI Recipe")

        XCTAssertTrue(app.waitForElement(app.staticTexts["Journey UI Recipe"], timeout: 5))
        XCTAssertTrue(app.otherElements[AccessibilityID.Journey.myRecipes].exists)
    }

    private func openCreateRecipe() {
        app.tapJourneyTab()
        app.tapElement(withIdentifier: AccessibilityID.Journey.createRecipeCard)
        XCTAssertTrue(app.waitForElement(app.textFields[AccessibilityID.CreateRecipe.recipeName], timeout: 5))
    }

    private func createRecipe(named name: String) {
        openCreateRecipe()

        let recipeName = app.firstMatch(for: AccessibilityID.CreateRecipe.recipeName)
        recipeName.tap()
        recipeName.typeText(name)
        app.tapElement(withIdentifier: AccessibilityID.CreateRecipe.nextButton)

        let ingredient0 = app.firstMatch(for: AccessibilityID.CreateRecipe.ingredient(0))
        ingredient0.tap()
        ingredient0.typeText("Flour")
        app.tapElement(withIdentifier: AccessibilityID.CreateRecipe.addIngredient)

        let ingredient1 = app.firstMatch(for: AccessibilityID.CreateRecipe.ingredient(1))
        XCTAssertTrue(ingredient1.waitForExistence(timeout: 5))
        ingredient1.tap()
        ingredient1.typeText("Water")
        app.tapElement(withIdentifier: AccessibilityID.CreateRecipe.nextButton)

        let step0 = app.firstMatch(for: AccessibilityID.CreateRecipe.step(0))
        step0.tap()
        step0.typeText("Mix everything together.")
        app.tapElement(withIdentifier: AccessibilityID.CreateRecipe.addStep)

        let step1 = app.firstMatch(for: AccessibilityID.CreateRecipe.step(1))
        XCTAssertTrue(step1.waitForExistence(timeout: 5))
        step1.tap()
        step1.typeText("Bake until golden.")
        app.tapElement(withIdentifier: AccessibilityID.CreateRecipe.nextButton)

        app.tapElement(withIdentifier: AccessibilityID.CreateRecipe.nextButton)
        app.tapElement(withIdentifier: AccessibilityID.CreateRecipe.nextButton)
        app.tapElement(withIdentifier: AccessibilityID.CreateRecipe.saveButton)
    }
}
