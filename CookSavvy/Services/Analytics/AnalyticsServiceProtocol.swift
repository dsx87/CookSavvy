import Foundation

enum AnalyticsEvent: String {
    case appOpened = "app_opened"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case cameraScanStarted = "camera_scan_started"
    case recipeSearchPerformed = "recipe_search_performed"
    case recipeViewed = "recipe_viewed"
    case recipeFavorited = "recipe_favorited"
    case recipeCooked = "recipe_cooked"
    case upgradeScreenViewed = "upgrade_screen_viewed"
    case upgradePurchased = "upgrade_purchased"
    case upgradeDismissed = "upgrade_dismissed"
    case scanLimitHit = "scan_limit_hit"
}

protocol AnalyticsServiceProtocol: AnyObject {
    func track(_ event: AnalyticsEvent, properties: [String: String])
    func track(_ event: AnalyticsEvent)
}
