import XCTest

final class DiscoverEmptyStateUITests: FreshInstallUITest {
    func testEmptyDiscoverStateDisplayed() {
        launchApp(extraLaunchArguments: ["--empty-db"])

        let emptyStateView = app.otherElements[AccessibilityID.Discover.emptyState]
        XCTAssertTrue(app.waitForElement(emptyStateView, timeout: 5), "Empty state view should be visible")

        let emptyTitle = app.staticTexts["Your fridge is waiting"]
        XCTAssertTrue(app.waitForElement(emptyTitle, timeout: 5), "Empty state title should be visible")

        let emptySubtitle = app.staticTexts["Scan your fridge or pick ingredients below to rescue dinner"]
        XCTAssertTrue(app.waitForElement(emptySubtitle, timeout: 5), "Empty state subtitle should be visible")
    }

    func testEmptyStateDisappearsWhenIngredientSelected() {
        launchApp(extraLaunchArguments: ["--empty-db"])

        let emptyStateView = app.otherElements[AccessibilityID.Discover.emptyState]
        XCTAssertTrue(app.waitForElement(emptyStateView, timeout: 5), "Empty state should be visible initially")

        app.selectIngredient("Garlic")

        XCTAssertTrue(app.waitForDisappearance(of: emptyStateView, timeout: 5), "Empty state should disappear when ingredient is selected")
    }

    func testEmptyStateWithAllSectionsHidden() {
        // Use empty-db to remove recent/saved/suggested/collections
        launchApp(extraLaunchArguments: ["--empty-db"])

        let emptyStateView = app.otherElements[AccessibilityID.Discover.emptyState]
        XCTAssertTrue(app.waitForElement(emptyStateView, timeout: 5), "Empty state should be visible when all sections are empty")

        // Verify all sections are hidden
        XCTAssertFalse(app.otherElements[AccessibilityID.Discover.recentSection].exists, "Recent section should not be visible")
        XCTAssertFalse(app.otherElements[AccessibilityID.Discover.savedSection].exists, "Saved section should not be visible")
        XCTAssertFalse(app.otherElements[AccessibilityID.Discover.suggestedSection].exists, "Suggested section should not be visible")
    }
}

final class DiscoverNoResultsStateUITests: FreeUserUITest {
    func testNoResultsStateAbsentWhenResultsExist() {
        app.selectIngredient("Garlic")
        app.tapFindRecipes()

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.bestMatch], timeout: 10), "Results should be visible")
        XCTAssertFalse(app.otherElements[AccessibilityID.Discover.noResultsState].exists, "No-results state must not appear when recipes are found")
    }

    func testSearchStateTransition() {
        // Select ingredients and search
        app.selectIngredient("Garlic")
        app.selectIngredient("Pasta")
        app.tapFindRecipes()

        // Wait for results to load
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.bestMatch], timeout: 10), "Recipe results should be visible")

        // Edit to return to ingredient selection
        app.buttons["Edit"].tap()

        // Verify we return to ingredient grid
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.ingredientGrid], timeout: 5), "Should return to ingredient selection")
    }
}
