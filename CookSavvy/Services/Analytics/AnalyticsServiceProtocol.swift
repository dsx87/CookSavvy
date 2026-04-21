import Foundation

enum AnalyticsEvent: String {
    case appOpened = "app_opened"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case onboardingCameraScanCompleted = "onboarding_camera_scan_completed"
    case onboardingTypeInsteadTapped = "onboarding_type_instead_tapped"
    case cameraScanStarted = "camera_scan_started"
    case recipeSearchPerformed = "recipe_search_performed"
    case recipeViewed = "recipe_viewed"
    case recipeFavorited = "recipe_favorited"
    case recipeCooked = "recipe_cooked"
    case upgradeScreenViewed = "upgrade_screen_viewed"
    case upgradePurchased = "upgrade_purchased"
    case upgradeDismissed = "upgrade_dismissed"
    case scanLimitHit = "scan_limit_hit"
    case anonymousAuthCompleted = "anonymous_auth_completed"
    case signInWithAppleStarted = "sign_in_with_apple_started"
    case signInWithAppleCompleted = "sign_in_with_apple_completed"
    case signInWithAppleFailed = "sign_in_with_apple_failed"
    case signOutCompleted = "sign_out_completed"
}

protocol AnalyticsServiceProtocol: AnyObject {
    func track(_ event: AnalyticsEvent, properties: [String: String])
    func track(_ event: AnalyticsEvent)
}
