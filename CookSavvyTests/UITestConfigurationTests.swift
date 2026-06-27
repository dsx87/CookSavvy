import XCTest
@testable import CookSavvy

final class UITestConfigurationTests: XCTestCase {

    @MainActor
    func testFromArgumentsAllowsFreshInstallAndSkipOnboardingTogether() async {
        let config = UITestConfiguration.fromArguments([
            "CookSavvy",
            "--uitesting",
            "--fresh-install",
            "--skip-onboarding"
        ])

        XCTAssertTrue(config.isUITesting)
        XCTAssertTrue(config.isFreshInstall)
        XCTAssertTrue(config.skipOnboarding)
    }

    @MainActor
    func testPrepareDefaultsKeepsFreshInstallWhenNotSkippingOnboarding() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "hasCompletedOnboarding")

        let config = UITestConfiguration(
            isUITesting: true,
            isFreshInstall: true,
            isPremiumUser: false,
            skipOnboarding: false,
            withCookingHistory: false,
            withFavorites: false,
            withShoppingItems: false
        )

        config.prepareDefaults(defaults)

        XCTAssertEqual(defaults.object(forKey: "hasCompletedOnboarding") as? Bool, false)
    }

    @MainActor
    func testPrepareDefaultsSetsOnboardingCompleteWhenSkipping() async {
        let defaults = makeDefaults()

        let config = UITestConfiguration(
            isUITesting: true,
            isFreshInstall: true,
            isPremiumUser: false,
            skipOnboarding: true,
            withCookingHistory: false,
            withFavorites: false,
            withShoppingItems: false
        )

        config.prepareDefaults(defaults)

        XCTAssertEqual(defaults.object(forKey: "hasCompletedOnboarding") as? Bool, true)
    }

    @MainActor
    private func makeDefaults() -> UserDefaults {
        let suiteName = "UITestConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
