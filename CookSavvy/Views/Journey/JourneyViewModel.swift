import SwiftUI

@MainActor
protocol JourneyCoordinating: RecipeDetailsCoordinating {
    func showRecipeDetail(recipe: Recipe)
    func showRecipeList(title: String, recipes: [Recipe])
    func showCreateRecipe()
    func showSettings()
}

@MainActor
final class JourneyViewModel: ObservableObject {

    @Published var recipesCooked: Int = 0
    @Published var dayStreak: Int = 0
    @Published var hoursCooking: Double = 0
    @Published var uniqueIngredientsUsed: Int = 0
    @Published var monthlyRecipesCooked: Int = 0
    @Published var monthlyIngredientsRescued: Int = 0
    @Published var savedRecipes: [Recipe] = []
    @Published var userRecipes: [Recipe] = []
    @Published var weekCookingDates: Set<Int> = []
    @Published var achievements: [Achievement] = Achievement.allAchievements
    @Published var recentSessions: [CookingSession] = []
    @Published var isLoading = false

    private let userDataService: UserDataServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let cameraScanTracker: CameraScanTrackerProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private weak var coordinator: (any JourneyCoordinating)?
    private var hasLoadedData = false

    init(
        userDataService: UserDataServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        cameraScanTracker: CameraScanTrackerProtocol,
        analyticsService: AnalyticsServiceProtocol,
        coordinator: (any JourneyCoordinating)? = nil
    ) {
        self.userDataService = userDataService
        self.subscriptionService = subscriptionService
        self.cameraScanTracker = cameraScanTracker
        self.analyticsService = analyticsService
        self.coordinator = coordinator
    }

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

    var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    var subscriptionHasShoppingListAccess: Bool {
        subscriptionService.canAccessFeature(.shoppingList)
    }

    var weekdayLabels: [String] {
        ["M", "T", "W", "T", "F", "S", "S"]
    }

    func loadDataIfNeeded() async {
        guard !hasLoadedData else { return }
        hasLoadedData = true
        await loadData()
    }

    func reloadDataOnAppear() {
        guard hasLoadedData else { return }
        Task {
            await loadData()
        }
    }

    func loadData() async {
        isLoading = true
        async let statsTask: () = loadStats()
        async let savedTask: () = loadSavedRecipes()
        async let recipesTask: () = loadUserRecipes()
        async let weekTask: () = loadWeekActivity()
        async let sessionsTask: () = loadRecentSessions()
        _ = await (statsTask, savedTask, recipesTask, weekTask, sessionsTask)
        await refreshAchievements()
        isLoading = false
    }

    func refreshRecipeCollections() async {
        async let savedTask: () = loadSavedRecipes()
        async let recipesTask: () = loadUserRecipes()
        _ = await (savedTask, recipesTask)
    }

    // MARK: - Navigation

    func showRecipeDetails(_ recipe: Recipe) {
        coordinator?.showRecipeDetail(recipe: recipe)
    }

    func showRecipeList(title: String, recipes: [Recipe]) {
        coordinator?.showRecipeList(title: title, recipes: recipes)
    }

    func showCreateRecipe() {
        coordinator?.showCreateRecipe()
    }

    func showSettings() {
        coordinator?.showSettings()
    }

    func showShoppingList() {
        if subscriptionService.canAccessFeature(.shoppingList) {
            coordinator?.showShoppingList()
        } else {
            coordinator?.showUpgrade()
        }
    }

    // MARK: - Week Calendar Helpers

    func isActiveDay(_ dayIndex: Int) -> Bool {
        weekCookingDates.contains(dayIndex)
    }

    func isTodayIndex(_ dayIndex: Int) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let mondayBased = (weekday + 5) % 7
        return dayIndex == mondayBased
    }

    // MARK: - Private

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
            print("❌ Failed to load journey stats: \(error)")
        }
    }

    private func loadUserRecipes() async {
        do {
            userRecipes = try await userDataService.getUserRecipes()
        } catch {
            print("❌ Failed to load user recipes: \(error)")
        }
    }

    private func loadSavedRecipes() async {
        do {
            savedRecipes = try await userDataService.getFavorites()
        } catch {
            print("❌ Failed to load saved recipes: \(error)")
        }
    }

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
        } catch {}
    }

    private func loadRecentSessions() async {
        do {
            recentSessions = try await userDataService.getCookingSessions(limit: 5)
        } catch {}
    }

    private func refreshAchievements() async {
        let highMatchCooks = UserDefaults.standard.integer(forKey: "high_match_cooks_count")
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
}
