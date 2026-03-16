import XCTest

final class SettingsUITests: FreeUserUITest {
    func testSettingsDisplay() {
        app.openJourneySettings()

        XCTAssertTrue(app.waitForElement(app.firstMatch(for: AccessibilityID.Settings.subscriptionSection), timeout: 10))
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.waitForElement(app.firstMatch(for: AccessibilityID.Settings.versionLabel), timeout: 10))
    }

    func testClearRecentData() {
        app.openRecipeResult("Test Garlic Pasta")
        XCTAssertTrue(app.waitForElement(app.staticTexts["Test Garlic Pasta"], timeout: 5))
        app.goBack()

        app.openJourneySettings()
        app.swipeUp()
        app.tapElement(withIdentifier: AccessibilityID.Settings.clearRecent)
        app.alerts.buttons["Clear"].tap()

        app.goBack()
        app.tapDiscoverTab()

        XCTAssertTrue(app.waitForDisappearance(of: app.otherElements[AccessibilityID.Discover.recentSection], timeout: 5))
        XCTAssertTrue(app.otherElements[AccessibilityID.Discover.savedSection].exists)
    }
}
