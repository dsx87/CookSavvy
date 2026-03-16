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
            withShoppingItems: args.contains("--with-shopping-items")
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
    }
}
#endif
