//
//  UITestConfiguration.swift
//  CookSavvy
//

#if DEBUG
import Foundation

/// Configuration parsed from XCUITest launch arguments that controls how the app bootstraps for UI testing.
///
/// Each property maps to a specific launch argument. The struct is created once at startup in
/// `ThemedAppRoot.init()` and passed to `AppContainer.configureForUITesting(_:)` and
/// `prepareDefaults(_:)` to establish a fully deterministic test environment.
struct UITestConfiguration {
    /// UserDefaults keys cleared and re-applied during test setup to ensure a clean state.
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let cameraScanTimestamps = "camera_scan_timestamps"
        static let enabledRecipeSources = "enabled_recipe_sources"
        static let themePreference = ThemePreference.storageKey
        static let cachedSubscriptionPlan = "cached_subscription_plan"
    }

    /// `--uitesting`: activates the deterministic test bootstrapping path.
    let isUITesting: Bool
    /// `--fresh-install`: forces first-launch onboarding regardless of persisted state.
    let isFreshInstall: Bool
    /// `--premium-user`: boots with a premium subscription via `MockSubscriptionService`.
    let isPremiumUser: Bool
    /// `--skip-onboarding`: marks onboarding complete so the main UI is shown immediately.
    ///
    /// Implied as `true` for any `--uitesting` run that is not also a `--fresh-install`.
    let skipOnboarding: Bool
    /// `--with-cooking-history`: seeds deterministic cooking sessions via `UITestDataSeeder`.
    let withCookingHistory: Bool
    /// `--with-favorites`: seeds the first two recipes as favorites.
    let withFavorites: Bool
    /// `--with-shopping-items`: seeds a small set of shopping list items.
    let withShoppingItems: Bool
    /// `--empty-db`: skips all database seeding for empty-state test coverage.
    let isEmptyDatabase: Bool
    /// `--large-dataset`: extends the default recipe set with 125 additional entries for scroll/pagination tests.
    let withLargeDataset: Bool
    /// `--camera-limit-reached`: fills the rolling 7-day camera-scan window to its free-tier cap.
    let hasReachedCameraLimit: Bool
    /// `--signed-in-apple`: boots with a mock Apple-authenticated (non-anonymous) session.
    let isSignedInWithApple: Bool

    /// Memberwise initializer; `skipOnboarding` defaults to `true` for any non-fresh-install UI test.
    init(
        isUITesting: Bool,
        isFreshInstall: Bool,
        isPremiumUser: Bool,
        skipOnboarding: Bool,
        withCookingHistory: Bool,
        withFavorites: Bool,
        withShoppingItems: Bool,
        isEmptyDatabase: Bool = false,
        withLargeDataset: Bool = false,
        hasReachedCameraLimit: Bool = false,
        isSignedInWithApple: Bool = false
    ) {
        self.isUITesting = isUITesting
        self.isFreshInstall = isFreshInstall
        self.isPremiumUser = isPremiumUser
        self.skipOnboarding = skipOnboarding
        self.withCookingHistory = withCookingHistory
        self.withFavorites = withFavorites
        self.withShoppingItems = withShoppingItems
        self.isEmptyDatabase = isEmptyDatabase
        self.withLargeDataset = withLargeDataset
        self.hasReachedCameraLimit = hasReachedCameraLimit
        self.isSignedInWithApple = isSignedInWithApple
    }

    /// Parses `ProcessInfo.processInfo.arguments` into a `UITestConfiguration`.
    static func fromLaunchArguments() -> UITestConfiguration {
        fromArguments(ProcessInfo.processInfo.arguments)
    }

    /// Parses an explicit argument list into a `UITestConfiguration`.
    ///
    /// `skipOnboarding` is derived as `true` whenever `--uitesting` is active and `--fresh-install`
    /// is absent, mirroring the default behaviour expected by almost all UI test suites.
    ///
    /// - Parameter args: The list of launch arguments to parse.
    static func fromArguments(_ args: [String]) -> UITestConfiguration {
        let isUITesting = args.contains("--uitesting")
        let isFreshInstall = args.contains("--fresh-install")
        return UITestConfiguration(
            isUITesting: isUITesting,
            isFreshInstall: isFreshInstall,
            isPremiumUser: args.contains("--premium-user"),
            skipOnboarding: args.contains("--skip-onboarding") || (isUITesting && !isFreshInstall),
            withCookingHistory: args.contains("--with-cooking-history"),
            withFavorites: args.contains("--with-favorites"),
            withShoppingItems: args.contains("--with-shopping-items"),
            isEmptyDatabase: args.contains("--empty-db"),
            withLargeDataset: args.contains("--large-dataset"),
            hasReachedCameraLimit: args.contains("--camera-limit-reached"),
            isSignedInWithApple: args.contains("--signed-in-apple")
        )
    }

    /// Resets and re-applies relevant UserDefaults keys so that each UI test starts from a known state.
    ///
    /// Clears onboarding completion, the camera scan-timestamp window, recipe source selection, theme
    /// preference, and cached subscription plan. Then writes the correct onboarding flag and, when
    /// `hasReachedCameraLimit` is set, fills the rolling scan window to the free-tier cap.
    ///
    /// - Parameter defaults: The `UserDefaults` suite to modify; defaults to `.standard`.
    func prepareDefaults(_ defaults: UserDefaults = .standard) {
        guard isUITesting else { return }

        [
            Keys.hasCompletedOnboarding,
            Keys.cameraScanTimestamps,
            Keys.enabledRecipeSources,
            Keys.themePreference,
            Keys.cachedSubscriptionPlan
        ].forEach { defaults.removeObject(forKey: $0) }

        defaults.set(!isFreshInstall || skipOnboarding, forKey: Keys.hasCompletedOnboarding)

        if hasReachedCameraLimit {
            // Fill the rolling window with `freeWeeklyLimit` scans dated now, so the gate reads as
            // exhausted (matching CameraScanTracker's timestamp-backed quota).
            let now = Date()
            let exhausted = Array(repeating: now, count: CameraScanTracker.freeWeeklyLimit)
            defaults.set(exhausted, forKey: Keys.cameraScanTimestamps)
        }
    }
}
#endif
