//
//  UITestConfiguration.swift
//  CookSavvy
//

#if DEBUG
import Foundation

struct UITestConfiguration {
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let cameraScansUsedThisWeek = "camera_scans_used_this_week"
        static let cameraScanWeekStart = "camera_scan_week_start"
        static let enabledRecipeSources = "enabled_recipe_sources"
        static let themePreference = ThemePreference.storageKey
        static let cachedSubscriptionPlan = "cached_subscription_plan"
    }

    let isUITesting: Bool
    let isFreshInstall: Bool
    let isPremiumUser: Bool
    let skipOnboarding: Bool
    let withCookingHistory: Bool
    let withFavorites: Bool
    let withShoppingItems: Bool
    let isEmptyDatabase: Bool
    let withLargeDataset: Bool
    let hasReachedCameraLimit: Bool

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
        hasReachedCameraLimit: Bool = false
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
    }

    static func fromLaunchArguments() -> UITestConfiguration {
        fromArguments(ProcessInfo.processInfo.arguments)
    }

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
            hasReachedCameraLimit: args.contains("--camera-limit-reached")
        )
    }

    func prepareDefaults(_ defaults: UserDefaults = .standard) {
        guard isUITesting else { return }

        [
            Keys.hasCompletedOnboarding,
            Keys.cameraScansUsedThisWeek,
            Keys.cameraScanWeekStart,
            Keys.enabledRecipeSources,
            Keys.themePreference,
            Keys.cachedSubscriptionPlan
        ].forEach { defaults.removeObject(forKey: $0) }

        defaults.set(!isFreshInstall || skipOnboarding, forKey: Keys.hasCompletedOnboarding)

        if hasReachedCameraLimit {
            defaults.set(CameraScanTracker.freeWeeklyLimit, forKey: Keys.cameraScansUsedThisWeek)
            defaults.set(Date(), forKey: Keys.cameraScanWeekStart)
        }
    }
}
#endif
