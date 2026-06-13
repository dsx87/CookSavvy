//
//  SettingsViewModel.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI
import Combine

/// Internal constants for Settings defaults, URLs, and query limits.
private enum SettingsViewModelConstants {
    static let unknownValue = "Unknown"
    static let manageSubscriptionURL = "https://apps.apple.com/account/subscriptions"
    static let recentRecipeStatsLimit = 1000
}

/// ViewModel backing the Settings screen.
///
/// Aggregates all user-configurable and account-related state:
/// - Current subscription plan (live-updated via publisher)
/// - Database stats: total recipes, favourites, and recent recipe counts
/// - Theme preference (light / dark / system)
/// - Dietary restrictions (toggled per restriction)
/// - Auth state (anonymous vs. Sign in with Apple) and sign-in/sign-out actions
/// - Subscription restore and upgrade navigation
@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The user's current subscription plan (updated live from `SubscriptionServiceProtocol`).
    @Published private(set) var currentPlan: SubscriptionPlan = .free
    /// The user's current subscription snapshot, including any active trial state.
    @Published private(set) var currentSubscriptionStatus: SubscriptionStatus = .free()
    /// Total number of recipes in the local database.
    @Published var recipeCount: Int = 0
    /// Number of recipes the user has bookmarked/saved.
    @Published var favoriteCount: Int = 0
    /// Number of recipes in the recent-recipes list.
    @Published var recentRecipeCount: Int = 0
    /// `true` while any async operation (load/clear) is in progress.
    @Published var isLoading: Bool = false
    /// Controls the "Clear Recent" confirmation alert.
    @Published var showClearRecentAlert: Bool = false
    /// Controls the "Clear Favourites" confirmation alert.
    @Published var showClearFavoritesAlert: Bool = false
    /// `true` while a restore-purchases request is in flight.
    @Published var isRestoringPurchases: Bool = false
    /// Non-`nil` when a restore-purchases request fails.
    @Published var restoreError: String?
    /// Non-`nil` when any general action fails; drives the error alert.
    @Published var errorMessage: String?
    /// The user's selected app appearance preference.
    @Published var themePreference: ThemePreference = .defaultValue
    /// The current authentication state (unknown / anonymous / signed in).
    @Published private(set) var authState: AuthState = .unknown
    /// `true` when the current session is anonymous (not linked to Apple ID).
    @Published private(set) var isAnonymous: Bool = true
    /// `true` while a Sign in with Apple flow is in flight.
    @Published var isSigningIn: Bool = false
    /// Controls the sign-out confirmation alert.
    @Published var showSignOutConfirmation: Bool = false
    /// Controls the delete-account confirmation alert.
    @Published var showDeleteAccountConfirmation: Bool = false
    /// `true` while an account-deletion request is in flight.
    @Published var isDeletingAccount: Bool = false

    /// `true` when auth is available on this device/build configuration.
    var isAuthAvailable: Bool {
        authService.isAuthAvailable
    }

    /// `true` when the user has linked their account via Sign in with Apple.
    var isSignedInWithApple: Bool {
        !isAnonymous && currentUserId != nil
    }

    /// The authenticated user ID when signed in with Apple, or `nil` for anonymous sessions.
    var currentUserId: String? {
        if case .signedIn(let userId) = authState {
            return userId
        }
        return nil
    }

    /// Title shown in the subscription row, upgraded to a trial-specific label when needed.
    var subscriptionTitle: String {
        currentSubscriptionStatus.isOnFreeTrial
            ? Strings.Settings.trialPlanTitle
            : currentPlan.displayName
    }

    /// Subtitle shown in the subscription row, including the trial end date when available.
    var subscriptionDescription: String {
        guard currentSubscriptionStatus.isOnFreeTrial else {
            return currentPlan.description
        }

        if let trialEndDate = currentSubscriptionStatus.formattedTrialEndDate {
            return String(format: Strings.Settings.trialDescriptionWithDate, trialEndDate)
        }

        return Strings.Settings.trialDescription
    }

    // MARK: - Properties

    /// The app's marketing version string (e.g. "1.2.0").
    let appVersion: String
    /// The build number string (e.g. "42").
    let buildNumber: String

    private let userDataService: UserDataServiceProtocol
    private let dbInterface: StatisticsStoreProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let dietaryPreferences: DietaryPreferencesProtocol
    private let authService: AuthServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let signInWithAppleAction: SignInWithAppleActionProtocol
    private let logger: any LoggerProtocol
    private weak var coordinator: SettingsCoordinator?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates a settings view model with persisted-user, subscription, and auth dependencies.
    init(
        userDataService: UserDataServiceProtocol,
        dbInterface: StatisticsStoreProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        dietaryPreferences: DietaryPreferencesProtocol,
        authService: AuthServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        signInWithAppleAction: SignInWithAppleActionProtocol,
        logger: any LoggerProtocol,
        coordinator: SettingsCoordinator?
    ) {
        self.userDataService = userDataService
        self.dbInterface = dbInterface
        self.subscriptionService = subscriptionService
        self.dietaryPreferences = dietaryPreferences
        self.authService = authService
        self.analyticsService = analyticsService
        self.signInWithAppleAction = signInWithAppleAction
        self.logger = logger
        self.coordinator = coordinator

        // Get app version info
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.appVersion = version
        } else {
            self.appVersion = SettingsViewModelConstants.unknownValue
        }

        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.buildNumber = build
        } else {
            self.buildNumber = SettingsViewModelConstants.unknownValue
        }
        
        currentSubscriptionStatus = subscriptionService.currentSubscriptionStatus
        currentPlan = currentSubscriptionStatus.plan

        subscriptionService.currentSubscriptionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.currentSubscriptionStatus = status
                self?.currentPlan = status.plan
            }
            .store(in: &cancellables)

        themePreference = userDataService.getThemePreference()

        authState = authService.authState
        isAnonymous = authService.isAnonymous
        isSigningIn = signInWithAppleAction.isSigningIn
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.authState = state
                self?.isAnonymous = self?.authService.isAnonymous ?? true
            }
            .store(in: &cancellables)
        signInWithAppleAction.isSigningInPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSigningIn in
                self?.isSigningIn = isSigningIn
            }
            .store(in: &cancellables)
    }
    
    /// Navigates to the subscription upgrade paywall.
    func showUpgrade() {
        coordinator?.showUpgrade()
    }

    /// Initiates a Sign in with Apple flow, writing any error to `errorMessage`.
    func signInWithApple() async {
        errorMessage = nil
        errorMessage = await signInWithAppleAction.signIn(context: .settings).errorMessage
    }

    /// Signs out the current user and immediately creates a new anonymous session.
    ///
    /// Tracks the sign-out analytics event on success.
    /// Sets `errorMessage` if sign-out or anonymous session creation fails.
    func signOut() async {
        errorMessage = nil
        do {
            try await authService.signOut()
        } catch {
            logger.error("Sign out failed: \(String(describing: error))")
            errorMessage = Strings.Errors.actionFailed
            return
        }

        analyticsService.track(.signOutCompleted)
        logger.info("Signed out successfully")

        do {
            try await authService.signInAnonymously()
            logger.info("Reverted to anonymous session after sign-out")
        } catch {
            logger.error("Failed to create anonymous session after sign-out: \(String(describing: error))")
            errorMessage = Strings.Auth.signOutGuestFailed
        }
    }
    
    /// Permanently deletes the user's account (App Store Guideline 5.1.1(v)) and clears local
    /// personal data, then reverts to a fresh anonymous session so the app stays usable.
    ///
    /// Server-side deletion is performed by the backend via `authService.deleteAccount()`. On failure
    /// nothing is cleared and `errorMessage` is set. On success we clear the user's local caches and
    /// re-establish an anonymous session, mirroring the post-sign-out behaviour.
    func deleteAccount() async {
        errorMessage = nil
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await authService.deleteAccount()
        } catch {
            logger.error("Account deletion failed: \(type(of: error))")
            errorMessage = Strings.Settings.deleteAccountFailed
            return
        }

        analyticsService.track(.accountDeleted)
        logger.info("Account deleted successfully")

        // Clear local personal data (recents + favourites). The seeded recipe/ingredient catalogue is
        // not user-specific and is intentionally left intact.
        do {
            try await userDataService.clearRecentData()
            try await userDataService.clearFavorites()
        } catch {
            logger.error("Failed to clear local data after account deletion: \(type(of: error))")
        }

        // Re-establish an anonymous session so the app remains functional, as after sign-out.
        do {
            try await authService.signInAnonymously()
        } catch {
            logger.error("Failed to create anonymous session after account deletion: \(type(of: error))")
            errorMessage = Strings.Auth.signOutGuestFailed
        }
    }

    /// Restores previously purchased subscriptions via StoreKit.
    func restorePurchases() async {
        isRestoringPurchases = true
        restoreError = nil
        defer { isRestoringPurchases = false }
        
        do {
            try await subscriptionService.restorePurchases()
        } catch {
            restoreError = error.localizedDescription
        }
    }
    
    /// Persists the selected theme preference and updates `themePreference`.
    func updateThemePreference(_ themePreference: ThemePreference) {
        guard self.themePreference != themePreference else { return }
        self.themePreference = themePreference
        userDataService.setThemePreference(themePreference)
    }

    /// Returns `true` if the given dietary restriction is currently enabled.
    func isDietaryRestrictionActive(_ restriction: DietaryRestriction) -> Bool {
        dietaryPreferences.isActive(restriction)
    }

    /// Toggles the active state of the given dietary restriction.
    func toggleDietaryRestriction(_ restriction: DietaryRestriction) {
        dietaryPreferences.toggle(restriction)
    }

    /// Opens the App Store's subscription management page in Safari.
    // TODO: check the link
    func openManageSubscriptions() {
        if let url = URL(string: SettingsViewModelConstants.manageSubscriptionURL) {
            UIApplication.shared.open(url)
        }
    }

    /// Opens the hosted Terms of Use page in the system browser.
    func openTermsOfUse() {
        if let url = LegalLinks.termsOfUse {
            UIApplication.shared.open(url)
        }
    }

    /// Opens the hosted Privacy Policy page in the system browser.
    func openPrivacyPolicy() {
        if let url = LegalLinks.privacyPolicy {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Public Methods

    /// Loads all database stats (recipe count, favourites, recent count) needed for the screen.
    func loadSettings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Load database stats
            recipeCount = try await getRecipeCount()
            favoriteCount = try await getFavoriteCount()
            recentRecipeCount = try await getRecentRecipeCount()
        } catch {
            logger.error("Failed to load settings: \(String(describing: error))")
            errorMessage = Strings.Errors.settingsLoadFailed
        }
    }

    /// Clears the user's recent recipe history and reloads stats.
    func clearRecentData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await userDataService.clearRecentData()
            // Reload stats
            await loadSettings()
        } catch {
            logger.error("Failed to clear recent data: \(String(describing: error))")
            errorMessage = Strings.Errors.clearDataFailed
        }
    }

    /// Clears all saved/bookmarked recipes and reloads stats.
    func clearFavorites() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await userDataService.clearFavorites()
            // Reload stats
            await loadSettings()
        } catch {
            logger.error("Failed to clear favorites: \(String(describing: error))")
            errorMessage = Strings.Errors.clearDataFailed
        }
    }

    /// Dismisses the error alert.
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Returns the total number of recipes in the local database.
    private func getRecipeCount() async throws -> Int {
        return try await dbInterface.getRecipeCount()
    }

    /// Returns the count of saved/favourited recipes.
    private func getFavoriteCount() async throws -> Int {
        let favorites = try await userDataService.getFavorites()
        return favorites.count
    }

    /// Returns the count of recently viewed/cooked recipes (capped at `recentRecipeStatsLimit`).
    private func getRecentRecipeCount() async throws -> Int {
        let recent = try await userDataService.getRecentRecipes(limit: SettingsViewModelConstants.recentRecipeStatsLimit)
        return recent.count
    }
}
