import XCTest

final class OnboardingUITests: FreshInstallUITest {
    func testOnboardingFlowComplete() {
        XCTAssertTrue(app.waitForElement(app.buttons[AccessibilityID.Onboarding.getStartedButton], timeout: 5))

        for _ in 0..<3 {
            app.tapElement(withIdentifier: AccessibilityID.Onboarding.getStartedButton)
        }

        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 5))
    }

    func testOnboardingPersistence() {
        for _ in 0..<3 {
            app.tapElement(withIdentifier: AccessibilityID.Onboarding.getStartedButton)
        }

        relaunchApp(withBaseLaunchArguments: ["--uitesting"])

        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[AccessibilityID.Onboarding.getStartedButton].exists)
    }
}
