import Foundation

/// All trackable user events in CookSavvy.
///
/// Raw string values map directly to the event names emitted by the analytics backend.
enum AnalyticsEvent: String {
    /// Fired when the app is launched (cold or warm start).
    case appOpened = "app_opened"
    /// Fired when the user completes the full onboarding flow.
    case onboardingCompleted = "onboarding_completed"
    /// Fired when the user skips onboarding.
    case onboardingSkipped = "onboarding_skipped"
    /// Fired when a camera-based ingredient scan completes during onboarding.
    case onboardingCameraScanCompleted = "onboarding_camera_scan_completed"
    /// Fired when the user taps "Type Instead" on the onboarding camera page.
    case onboardingTypeInsteadTapped = "onboarding_type_instead_tapped"
    /// Fired when the user starts a camera scan for ingredient detection.
    case cameraScanStarted = "camera_scan_started"
    /// Fired when the user triggers a recipe search with selected ingredients.
    case recipeSearchPerformed = "recipe_search_performed"
    /// Fired when the user opens a recipe detail screen.
    case recipeViewed = "recipe_viewed"
    /// Fired when the user toggles a recipe as a favorite.
    case recipeFavorited = "recipe_favorited"
    /// Fired when the user marks a recipe as cooked.
    case recipeCooked = "recipe_cooked"
    /// Fired when the upgrade / paywall screen is displayed.
    case upgradeScreenViewed = "upgrade_screen_viewed"
    /// Fired when the user successfully purchases CookSavvy+.
    case upgradePurchased = "upgrade_purchased"
    /// Fired when the user dismisses the upgrade screen without purchasing.
    case upgradeDismissed = "upgrade_dismissed"
    /// Fired when the user begins the monthly introductory free trial.
    case trialStarted = "trial_started"
    /// Fired when the monthly free trial rolls into a paid premium subscription.
    case trialConverted = "trial_converted"
    /// Fired when the monthly free trial ends without an active paid subscription.
    case trialExpired = "trial_expired"
    /// Fired when a free-tier user reaches the weekly camera scan cap.
    case scanLimitHit = "scan_limit_hit"
    /// Fired when anonymous Supabase authentication completes successfully.
    case anonymousAuthCompleted = "anonymous_auth_completed"
    /// Fired when the Sign in with Apple flow is initiated.
    case signInWithAppleStarted = "sign_in_with_apple_started"
    /// Fired when Sign in with Apple completes successfully.
    case signInWithAppleCompleted = "sign_in_with_apple_completed"
    /// Fired when Sign in with Apple fails.
    case signInWithAppleFailed = "sign_in_with_apple_failed"
    /// Fired when the user signs out.
    case signOutCompleted = "sign_out_completed"
    /// Fired when the user deletes their account (App Store Guideline 5.1.1(v) flow).
    case accountDeleted = "account_deleted"
}

/// Protocol for tracking named user events with optional string properties.
///
/// The concrete `AnalyticsService` implementation writes to `os.Logger`; `MockAnalyticsService`
/// accumulates events in memory for testing. To adopt a third-party SDK, conform an adapter
/// to this protocol and register it in `AppContainer`.
protocol AnalyticsServiceProtocol: AnyObject {
    /// Tracks an event with a dictionary of additional string metadata.
    /// - Parameters:
    ///   - event: The event to track.
    ///   - properties: Key-value pairs to attach to the event (e.g. `["recipe_id": "42"]`).
    func track(_ event: AnalyticsEvent, properties: [String: String])

    /// Tracks an event with no additional properties.
    /// - Parameter event: The event to track.
    func track(_ event: AnalyticsEvent)
}
