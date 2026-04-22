import SwiftUI
import Combine

@MainActor
/// Coordinator interface consumed by ``JourneyViewModel`` for navigation actions.
protocol JourneyCoordinating: RecipeDetailsCoordinating {
    /// Opens recipe details for a selected recipe and selection context.
    func showRecipeDetail(recipe: Recipe, selectedIngredients: [Ingredient])
    /// Opens a titled recipe list screen.
    func showRecipeList(title: String, recipes: [Recipe])
    /// Presents the create-recipe flow.
    func showCreateRecipe()
    /// Navigates to the settings screen.
    func showSettings()
}

/// ViewModel backing the My Kitchen (Journey) screen.
///
/// Aggregates all personalised user data into one place:
/// - All-time and monthly cooking stats (meals cooked, cooking time, ingredients rescued)
/// - Weekly cooking activity for the 7-day dot calendar
/// - Saved/bookmarked recipes and user-created recipes
/// - Recent cooking sessions for the "Cook Again" history feed
/// - Achievement progress, evaluated lazily after each data load
/// - Sign in with Apple state, forwarded from `AuthServiceProtocol`
///
/// Delegates all navigation to `JourneyCoordinator` via a weak `coordinator` reference.
@MainActor
final class JourneyViewModel: ObservableObject {
    /// Total number of times the user has completed a cooking session (all-time).
    @Published var recipesCooked: Int = 0
    /// Current consecutive-day cooking streak (reserved for future display).
    @Published var dayStreak: Int = 0
    /// Total accumulated cooking time in hours (all-time).
    @Published var hoursCooking: Double = 0
    /// Count of unique ingredients the user has ever cooked with (all-time).
    @Published var uniqueIngredientsUsed: Int = 0
    /// Number of meals cooked in the current calendar month.
    @Published var monthlyRecipesCooked: Int = 0
    /// Number of ingredients "rescued" (used in cooking) in the current calendar month.
    @Published var monthlyIngredientsRescued: Int = 0
    /// Recipes the user has bookmarked/saved, shown in the saved recipes carousel.
    @Published var savedRecipes: [Recipe] = []
    /// Recipes created by the user, shown in the My Recipes carousel.
    @Published var userRecipes: [Recipe] = []
    /// Day-of-week indices (Monday = 0) on which the user cooked this week.
    @Published var weekCookingDates: Set<Int> = []
    /// The full achievement list, evaluated and updated after each data load.
    @Published var achievements: [Achievement] = Achievement.allAchievements
    /// Whether the achievements carousel is expanded to show all badges.
    @Published var isAchievementsExpanded = false
    /// The most recent cooking sessions, used in the recent activity feed.
    @Published var recentSessions: [CookingSession] = []
    /// `true` while any data load is in progress.
    @Published var isLoading = false
    /// Non-`nil` when a "Cook Again" recipe lookup failed; drives a dedicated alert.
    @Published var cookAgainErrorMessage: String?
    /// Non-`nil` when a general data load failed; drives the generic error alert.
    @Published var errorMessage: String?
    /// `true` when the current auth session is anonymous (not signed in with Apple).
    @Published private(set) var isAnonymous: Bool = true
    /// `true` while a Sign in with Apple request is in flight.
    @Published var isSigningIn: Bool = false

    /// `true` when auth is available on this device/build (may be hidden on unsupported configurations).
    var isAuthAvailable: Bool {
        authService.isAuthAvailable
    }

    /// `true` when the user has linked their account via Sign in with Apple.
    var isSignedInWithApple: Bool {
        !isAnonymous && authService.currentUserId != nil
    }

    private let userDataService: UserDataServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let cameraScanTracker: CameraScanTrackerProtocol
    private let authService: AuthServiceProtocol
    private let signInWithAppleAction: SignInWithAppleActionProtocol
    private let logger: any LoggerProtocol
    private weak var coordinator: (any JourneyCoordinating)?
    private var hasLoadedData = false
    private var cancellables = Set<AnyCancellable>()

    /// Creates the journey view model with all dependencies and optional coordinator.
    init(
        userDataService: UserDataServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        cameraScanTracker: CameraScanTrackerProtocol,
        authService: AuthServiceProtocol,
        signInWithAppleAction: SignInWithAppleActionProtocol,
        logger: any LoggerProtocol,
        coordinator: (any JourneyCoordinating)? = nil
    ) {
        self.userDataService = userDataService
        self.subscriptionService = subscriptionService
        self.cameraScanTracker = cameraScanTracker
        self.authService = authService
        self.signInWithAppleAction = signInWithAppleAction
        self.logger = logger
        self.coordinator = coordinator

        isAnonymous = authService.isAnonymous
        isSigningIn = signInWithAppleAction.isSigningIn
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
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

    /// Total cooking time formatted as a human-readable string (e.g. "2h 30m" or "45m").
    var cookingTimeFormatted: String {
        let totalMinutes = Int(hoursCooking * 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes)m"
        } else if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }

    /// The number of achievements the user has unlocked.
    var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    /// The subset of achievements in the `.antiWaste` category, shown in the compact card.
    var antiWasteAchievements: [Achievement] {
        achievements.filter { $0.category == .antiWaste }
    }

    /// `true` when the user's subscription tier includes the shopping list feature.
    var subscriptionHasShoppingListAccess: Bool {
        subscriptionService.canAccessFeature(.shoppingList)
    }

    /// Monday-indexed single-character day labels for the weekly activity dot row.
    var weekdayLabels: [String] {
        ["M", "T", "W", "T", "F", "S", "S"]
    }

    /// Loads all data once on first appearance; subsequent calls are no-ops.
    func loadDataIfNeeded() async {
        guard !hasLoadedData else { return }
        hasLoadedData = true
        await loadData()
    }

    /// Reloads data on `onAppear` for subsequent appearances (after first load has already run).
    func reloadDataOnAppear() {
        guard hasLoadedData else { return }
        Task {
            await loadData()
        }
    }

    /// Loads all screen data concurrently: stats, saved/user recipes, weekly activity, and recent sessions.
    func loadData() async {
        isLoading = true
        errorMessage = nil
        async let statsTask: () = loadStats()
        async let savedTask: () = loadSavedRecipes()
        async let recipesTask: () = loadUserRecipes()
        async let weekTask: () = loadWeekActivity()
        async let sessionsTask: () = loadRecentSessions()
        _ = await (statsTask, savedTask, recipesTask, weekTask, sessionsTask)
        await refreshAchievements()
        isLoading = false
    }

    /// Refreshes only the recipe collections (saved and user-created) without reloading stats.
    func refreshRecipeCollections() async {
        async let savedTask: () = loadSavedRecipes()
        async let recipesTask: () = loadUserRecipes()
        _ = await (savedTask, recipesTask)
    }

    // MARK: - Navigation

    /// Navigates to recipe detail for the given recipe (no ingredient selection context).
    func showRecipeDetails(_ recipe: Recipe) {
        coordinator?.showRecipeDetail(recipe: recipe, selectedIngredients: [])
    }

    /// Looks up the recipe associated with a past cooking session and navigates to its detail screen.
    /// Shows a `cookAgainErrorMessage` alert if the recipe can no longer be found.
    func cookAgain(session: CookingSession) async {
        do {
            guard let recipe = try await userDataService.getRecipe(byID: session.recipeId) else {
                presentCookAgainError()
                return
            }
            coordinator?.showRecipeDetail(recipe: recipe, selectedIngredients: [])
        } catch {
            logger.error("Failed to load recipe for cook again: \(String(describing: error))")
            presentCookAgainError()
        }
    }

    /// Dismisses the cook-again error alert.
    func dismissCookAgainError() {
        cookAgainErrorMessage = nil
    }

    /// Toggles whether the achievements section shows the compact card or the full scrollable carousel.
    func toggleAchievementsExpanded() {
        isAchievementsExpanded.toggle()
    }

    /// Dismisses the general error alert.
    func dismissError() {
        errorMessage = nil
    }

    /// Navigates to a titled list of recipes.
    func showRecipeList(title: String, recipes: [Recipe]) {
        coordinator?.showRecipeList(title: title, recipes: recipes)
    }

    /// Navigates to the create-recipe flow.
    func showCreateRecipe() {
        coordinator?.showCreateRecipe()
    }

    /// Navigates to the settings screen.
    func showSettings() {
        coordinator?.showSettings()
    }

    /// Opens the shopping list or the upgrade paywall, depending on the user's subscription tier.
    func showShoppingList() {
        if subscriptionService.canAccessFeature(.shoppingList) {
            coordinator?.showShoppingList()
        } else {
            coordinator?.showUpgrade()
        }
    }

    // MARK: - Auth

    /// Initiates a Sign in with Apple flow, propagating any error to `errorMessage`.
    func signInWithApple() async {
        errorMessage = nil
        errorMessage = await signInWithAppleAction.signIn(context: .journey).errorMessage
    }

    // MARK: - Week Calendar Helpers

    /// Returns `true` if the user cooked on the given Monday-indexed day this week.
    func isActiveDay(_ dayIndex: Int) -> Bool {
        weekCookingDates.contains(dayIndex)
    }

    /// Returns `true` if the given Monday-indexed day index corresponds to today.
    func isTodayIndex(_ dayIndex: Int) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let mondayBased = (weekday + 5) % 7
        return dayIndex == mondayBased
    }

    // MARK: - Private

    /// Fetches all-time and monthly stats concurrently from `UserDataService`.
    private func loadStats() async {
        do {
            recipesCooked = try await userDataService.recipesCooked()
            dayStreak = try await userDataService.currentStreak()
            let totalSeconds = try await userDataService.totalCookingTime()
            hoursCooking = totalSeconds / 3600.0
            uniqueIngredientsUsed = try await userDataService.getDistinctIngredientsUsedCount()
            monthlyRecipesCooked = try await userDataService.monthlyRecipesCooked()
            monthlyIngredientsRescued = try await userDataService.monthlyIngredientsRescued()
        } catch {
            logger.error("Failed to load journey stats: \(String(describing: error))")
            errorMessage = Strings.Errors.journeyLoadFailed
        }
    }

    /// Fetches user-created recipes.
    private func loadUserRecipes() async {
        do {
            userRecipes = try await userDataService.getUserRecipes()
        } catch {
            logger.error("Failed to load journey user recipes: \(String(describing: error))")
            errorMessage = Strings.Errors.journeyLoadFailed
        }
    }

    /// Fetches saved/favourited recipes.
    private func loadSavedRecipes() async {
        do {
            savedRecipes = try await userDataService.getFavorites()
        } catch {
            logger.error("Failed to load journey saved recipes: \(String(describing: error))")
            errorMessage = Strings.Errors.journeyLoadFailed
        }
    }

    /// Converts cooking dates from `UserDataService` into Monday-indexed day indices for the dot calendar.
    private func loadWeekActivity() async {
        do {
            let dates = try await userDataService.getWeekCookingDates()
            let calendar = Calendar.current
            var daySet: Set<Int> = []
            for date in dates {
                let weekday = calendar.component(.weekday, from: date)
                let mondayBased = (weekday + 5) % 7
                daySet.insert(mondayBased)
            }
            weekCookingDates = daySet
        } catch {
            logger.error("Failed to load journey week activity: \(String(describing: error))")
        }
    }

    /// Fetches the most recent cooking sessions (capped at 5) for the activity feed.
    private func loadRecentSessions() async {
        do {
            recentSessions = try await userDataService.getCookingSessions(limit: 5)
        } catch {
            logger.error("Failed to load journey recent sessions: \(String(describing: error))")
        }
    }

    /// Evaluates achievement progress from the current metrics and updates `achievements`.
    ///
    /// Pulls high-match cook count, total camera scans, and distinct recipe IDs from all cooking sessions
    /// before passing them to `AchievementEvaluator`.
    private func refreshAchievements() async {
        let highMatchCooks = userDataService.getHighMatchRecipesCookedCount()
        let totalScans = cameraScanTracker.totalScansRecorded()
        do {
            let allSessions = try await userDataService.getCookingSessions(limit: max(recipesCooked, 50))
            let distinctRecipesCooked = Set(allSessions.map(\.recipeId)).count
            achievements = AchievementEvaluator.evaluate(
                metrics: AchievementMetrics(
                    recipesCooked: recipesCooked,
                    dayStreak: dayStreak,
                    totalCookingHours: hoursCooking,
                    userRecipeCount: userRecipes.count,
                    distinctRecipesCooked: distinctRecipesCooked,
                    highMatchRecipesCooked: highMatchCooks,
                    uniqueIngredientsUsed: uniqueIngredientsUsed,
                    totalCameraScans: totalScans
                )
            )
        } catch {
            logger.error("Failed to refresh journey achievements: \(String(describing: error))")
            achievements = AchievementEvaluator.evaluate(
                metrics: AchievementMetrics(
                    recipesCooked: recipesCooked,
                    dayStreak: dayStreak,
                    totalCookingHours: hoursCooking,
                    userRecipeCount: userRecipes.count,
                    distinctRecipesCooked: 0,
                    highMatchRecipesCooked: highMatchCooks,
                    uniqueIngredientsUsed: uniqueIngredientsUsed,
                    totalCameraScans: totalScans
                )
            )
        }
    }

    /// Sets a localized "cook again" failure message for the dedicated alert.
    private func presentCookAgainError() {
        cookAgainErrorMessage = Strings.Journey.cookAgainErrorMessage
    }
}
