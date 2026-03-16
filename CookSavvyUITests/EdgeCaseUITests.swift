import XCTest

final class EdgeCaseUITests: BaseUITest {
    func testEmptyDBNoCrash() {
        relaunchApp(extraLaunchArguments: ["--empty-db"])

        XCTAssertTrue(app.waitForElement(app.textFields[AccessibilityID.Discover.searchField], timeout: 5))
        XCTAssertTrue(app.otherElements[AccessibilityID.Discover.ingredientGrid].exists)
    }

    func testRapidTabSwitching() {
        for _ in 0..<4 {
            app.tapJourneyTab()
            app.tapDiscoverTab()
        }

        XCTAssertTrue(app.waitForElement(app.textFields[AccessibilityID.Discover.searchField], timeout: 5))
    }

    func testLargeDataSet() {
        relaunchApp(extraLaunchArguments: ["--large-dataset", "--with-cooking-history", "--with-favorites"])

        app.selectIngredient("Garlic")
        app.tapFindRecipes()

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Discover.moreRecipes], timeout: 10))
        XCTAssertTrue(app.otherElements[AccessibilityID.Discover.recipe("Large Test Garlic Skillet 1-1")].exists || app.otherElements[AccessibilityID.Discover.recipe("Test Garlic Pasta")].exists)
    }
}
