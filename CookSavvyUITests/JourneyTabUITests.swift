import XCTest

final class JourneyTabUITests: FreeUserUITest {
    override func setUp() {
        super.setUp()
        app.tapJourneyTab()
    }

    func testStatsDisplay() {
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Journey.Stats.recipesCooked], timeout: 5))
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Journey.Stats.dayStreak], timeout: 5))
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Journey.Stats.hoursCooking], timeout: 5))
    }

    func testWeeklyCalendar() {
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Journey.weeklyActivity], timeout: 5))
    }

    func testAchievements() {
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Journey.achievements], timeout: 5))
    }

    func testRecentSessions() {
        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Journey.recentActivity], timeout: 5))
        XCTAssertTrue(app.staticTexts["Test Garlic Pasta"].exists || app.staticTexts["Test Lemon Chicken"].exists)
    }

    func testSettingsNav() {
        app.tapElement(withIdentifier: AccessibilityID.Journey.settingsButton)

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Settings.subscriptionSection], timeout: 5))
    }
}
