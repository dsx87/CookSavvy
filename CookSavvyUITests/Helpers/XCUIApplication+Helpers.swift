import XCTest

extension XCUIApplication {
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    @discardableResult
    func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func firstMatch(for identifier: String) -> XCUIElement {
        let candidates = [
            buttons.matching(identifier: identifier).element(boundBy: 0),
            otherElements.matching(identifier: identifier).element(boundBy: 0),
            staticTexts.matching(identifier: identifier).element(boundBy: 0),
            textFields.matching(identifier: identifier).element(boundBy: 0),
            secureTextFields.matching(identifier: identifier).element(boundBy: 0),
            images.matching(identifier: identifier).element(boundBy: 0),
            cells.matching(identifier: identifier).element(boundBy: 0),
            switches.matching(identifier: identifier).element(boundBy: 0),
            tabBars.buttons.matching(identifier: identifier).element(boundBy: 0),
            descendants(matching: .any).matching(identifier: identifier).element(boundBy: 0)
        ]

        if let match = candidates.first(where: \.exists) {
            return match
        }

        return descendants(matching: .any).matching(identifier: identifier).element(boundBy: 0)
    }

    func tapElement(withIdentifier identifier: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let element = firstMatch(for: identifier)
        XCTAssertTrue(waitForElement(element, timeout: timeout), "Missing element \(identifier)", file: file, line: line)
        element.tap()
    }

    func tapDiscoverTab() {
        let tab = tabBars.buttons["Discover"]
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
            return
        }
        tapElement(withIdentifier: AccessibilityID.Tab.discover)
    }

    func tapJourneyTab() {
        let tab = tabBars.buttons["Journey"]
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
            return
        }
        tapElement(withIdentifier: AccessibilityID.Tab.journey)
    }

    func selectIngredient(_ name: String) {
        tapElement(withIdentifier: AccessibilityID.Discover.ingredient(name), timeout: 10)
    }

    func tapFindRecipes() {
        tapElement(withIdentifier: AccessibilityID.Discover.findRecipesButton, timeout: 10)
    }

    func openRecipeResult(_ title: String) {
        let recipeElement = firstMatch(for: AccessibilityID.Discover.recipe(title))
        XCTAssertTrue(waitForElement(recipeElement, timeout: 10), "Recipe '\(title)' not found in results")
        recipeElement.tap()
    }

    func navigateToRecipeDetail(ingredients: [String], recipeTitle: String) {
        tapDiscoverTab()
        for ingredient in ingredients {
            selectIngredient(ingredient)
        }
        tapFindRecipes()
        openRecipeResult(recipeTitle)
    }

    func openJourneySettings() {
        tapJourneyTab()
        tapElement(withIdentifier: AccessibilityID.Journey.settingsButton)
    }

    func goBack() {
        let backButton = navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 2) {
            backButton.tap()
        } else {
            swipeRight()
        }
    }
}

extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        tap()

        guard let currentValue = value as? String else {
            typeText(text)
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        typeText(deleteString + text)
    }
}
