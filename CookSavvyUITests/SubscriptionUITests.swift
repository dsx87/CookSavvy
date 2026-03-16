import XCTest

final class SubscriptionUITests: FreeUserUITest {
    func testUpgradeScreenDisplay() {
        app.openJourneySettings()
        app.tapElement(withIdentifier: AccessibilityID.Settings.upgradeButton)

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Upgrade.premiumPlan], timeout: 5))
        XCTAssertTrue(app.waitForElement(app.buttons[AccessibilityID.Upgrade.subscribeButton], timeout: 5))
    }

    func testFeatureGating() {
        relaunchApp(extraLaunchArguments: ["--camera-limit-reached"])

        app.tapElement(withIdentifier: AccessibilityID.Discover.cameraButton)

        XCTAssertTrue(app.waitForElement(app.otherElements[AccessibilityID.Upgrade.premiumPlan], timeout: 5))
    }
}
