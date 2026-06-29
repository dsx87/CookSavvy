//
//  UserDataService.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import Foundation
import GRDB

/// Default query limits and look-back windows used throughout `UserDataService`.
private enum UserDataServiceConstants {
    static let recentIngredientsLimit = 10
    static let recentRecipesLimit = 20
    static let recentSearchesLimit = 10
    static let cookingSessionsLimit = 50
    static let weekDurationDays = 7
    static let streakLookbackDays = 365
    static let singleDayOffset = -1
}

/// Manages all user-specific persistent data for CookSavvy.
///
/// Session data (cooking history, favorites, recent activity, user-created recipes) is
/// persisted in the GRDB SQLite database via `DBInterfaceProtocol`. Lightweight scalar
/// preferences (theme choice, high-match cook count) are stored in `UserDefaults`.
final class UserDataService: UserDataServiceProtocol {

    // MARK: - Properties

    private let dbInterface: DBInterfaceProtocol
    private let defaults: UserDefaults

    /// UserDefaults keys for lightweight user metrics and preference storage.
    private enum Keys {
        static let highMatchRecipesCookedCount = "high_match_cooks_count"
        static let themePreference = ThemePreference.storageKey
    }

    // MARK: - Initialization

    /// Creates a new `UserDataService`.
    /// - Parameters:
    ///   - dbInterface: The database layer used for persistent storage.
    ///   - defaults: The `UserDefaults` store for scalar preferences (defaults to `.standard`).
    init(dbInterface: DBInterfaceProtocol, defaults: UserDefaults = .standard) {
        self.dbInterface = dbInterface
        self.defaults = defaults
    }

    // MARK: - Recent Ingredients

    /// Gets the most recently used ingredients
    /// - Parameter limit: Maximum number of ingredients to return (default: 10)
    /// - Returns: Array of recent ingredients ordered by last used date
    func getRecentIngredients(limit: Int = UserDataServiceConstants.recentIngredientsLimit) async throws -> [Ingredient] {
        return try await dbInterface.getRecentIngredients(limit: limit)
    }

    /// Builds the personalized Discover quick-pick grid: the user's own recently-selected ingredients
    /// lead (most-recent-first), then the curated `PopularIngredients.seed()` fills any remaining slots.
    ///
    /// This is a *blend*, not an either/or: a fresh install (empty `recent_ingredients`) shows the full
    /// curated seed, and as the user's picks accumulate they push to the front while the curated set
    /// keeps the grid full underneath — so previously-selected ingredients and the remaining popular
    /// ones are shown together. Recency (`getRecentIngredients`, ordered by `last_used_at`) drives the
    /// lead so a freshly promoted pick lands first, matching the grid's move-to-front behaviour. Pantry
    /// staples are excluded from both halves since they are never offered for selection (see
    /// `PantryStaples`) — including any left in usage history from before that rule.
    /// - Parameter limit: Maximum number of ingredients to return (default: 10).
    /// - Returns: Recently-used ingredients (most-recent-first) followed by curated popular fill,
    ///   deduplicated case-insensitively and capped at `limit`.
    func getPopularIngredients(limit: Int = 10) async throws -> [Ingredient] {
        var recent: [Ingredient] = []
        do {
            recent = PantryStaples.excludingStaples(try await dbInterface.getRecentIngredients(limit: limit))
        } catch {
            // Ignore history-fetch failures and fall back to the curated seed alone below.
        }

        let curated = PantryStaples.excludingStaples(PopularIngredients.seed())
        return Array(Self.mergedPersonalizedGrid(recent: recent, curated: curated).prefix(limit))
    }

    /// Merges recently-used ingredients (kept first, most-recent-first) with the curated popular seed,
    /// dropping any curated entry that duplicates a recent one (case-insensitive). Preserves the
    /// recent-first ordering the Discover grid relies on for move-to-front personalization.
    private static func mergedPersonalizedGrid(recent: [Ingredient], curated: [Ingredient]) -> [Ingredient] {
        var seen = Set<String>()
        var result: [Ingredient] = []
        result.reserveCapacity(recent.count + curated.count)
        for ingredient in recent + curated {
            let key = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(ingredient)
        }
        return result
    }

    /// Records usage of multiple ingredients
    /// - Parameter ingredients: Array of ingredients to record
    func recordIngredientUsage(_ ingredients: [Ingredient]) async throws {
        for ingredient in ingredients {
            try await dbInterface.recordIngredientUsage(ingredient)
        }
    }

    // MARK: - Recent Recipes

    /// Gets the most recently viewed recipes
    /// - Parameter limit: Maximum number of recipes to return (default: 20)
    /// - Returns: Array of recent recipes ordered by last viewed date
    func getRecentRecipes(limit: Int = UserDataServiceConstants.recentRecipesLimit) async throws -> [Recipe] {
        return try await dbInterface.getRecentRecipes(limit: limit)
    }

    /// Fetches a recipe by its database ID.
    /// - Parameter id: The primary key of the recipe in the database.
    /// - Returns: The matching `Recipe`, or `nil` if none is found.
    func getRecipe(byID id: Int) async throws -> Recipe? {
        try await dbInterface.getRecipe(byID: id)
    }

    /// Records that a recipe was viewed
    /// - Parameter recipe: The recipe that was viewed
    func recordRecipeView(_ recipe: Recipe) async throws {
        // Get the recipe ID from the database by title
        if let recipeId = try await getRecipeId(byTitle: recipe.title) {
            try await dbInterface.recordRecipeView(recipeId)
        }
    }

    // MARK: - Favorites

    /// Gets all favorite recipes
    /// - Returns: Array of favorite recipes ordered by added date (newest first)
    func getFavorites() async throws -> [Recipe] {
        return try await dbInterface.getFavoriteRecipes()
    }

    /// Gets saved recipes, combining explicit favorites with user-created recipes.
    ///
    /// User-created recipes are always treated as implicitly saved, so this method merges both
    /// sets and deduplicates by recipe ID to avoid showing the same recipe twice.
    func getSavedRecipes() async throws -> [Recipe] {
        let favorites = try await dbInterface.getFavoriteRecipes()
        let userRecipes = try await dbInterface.getUserCreatedRecipes()

        var savedRecipes = favorites
        var seenRecipeIDs = Set(favorites.map(\.id))

        for recipe in userRecipes where seenRecipeIDs.insert(recipe.id).inserted {
            savedRecipes.append(recipe)
        }

        return savedRecipes
    }

    /// Toggles the favorite status of a recipe
    /// - Parameter recipe: The recipe to toggle
    /// - Returns: True if the recipe is now favorited, false if it was unfavorited
    func toggleFavorite(_ recipe: Recipe) async throws -> Bool {
        guard let recipeId = try await getRecipeId(byTitle: recipe.title) else {
            throw UserDataServiceError.recipeNotFound
        }

        if recipe.isUserCreated {
            if try await !dbInterface.isFavorite(recipeId) {
                try await dbInterface.addFavorite(recipeId)
            }
            return true
        }

        let isFavorited = try await dbInterface.isFavorite(recipeId)

        if isFavorited {
            try await dbInterface.removeFavorite(recipeId)
            return false
        } else {
            try await dbInterface.addFavorite(recipeId)
            return true
        }
    }

    /// Checks if a recipe is favorited
    /// - Parameter recipe: The recipe to check
    /// - Returns: True if the recipe is favorited, false otherwise
    func isFavorite(_ recipe: Recipe) async throws -> Bool {
        if recipe.isUserCreated {
            return true
        }
        guard let recipeId = try await getRecipeId(byTitle: recipe.title) else {
            return false
        }
        return try await dbInterface.isFavorite(recipeId)
    }

    // MARK: - Recent Searches

    /// Gets recent ingredient searches
    /// - Parameter limit: Maximum number of searches to return (default: 10)
    /// - Returns: Array of ingredient arrays representing past searches
    func getRecentSearches(limit: Int = UserDataServiceConstants.recentSearchesLimit) async throws -> [[Ingredient]] {
        return try await dbInterface.getRecentSearches(limit: limit)
    }

    /// Records a search with the given ingredients
    /// - Parameter ingredients: The ingredients that were searched for
    func recordSearch(ingredients: [Ingredient]) async throws {
        try await dbInterface.recordSearch(ingredients: ingredients)
    }

    // MARK: - Cooking Sessions

    /// Records a completed cooking session for a recipe.
    ///
    /// In addition to persisting the session, increments the `highMatchRecipesCookedCount`
    /// counter in `UserDefaults` when the recipe had no missing ingredients (i.e., a perfect
    /// ingredient match), which feeds the achievement system.
    /// - Parameters:
    ///   - recipe: The recipe that was cooked.
    ///   - duration: Time spent cooking, if tracked.
    ///   - rating: User's rating (1–5), if provided.
    func markAsCooked(recipe: Recipe, duration: TimeInterval? = nil, rating: Int? = nil) async throws {
        guard let recipeId = try await getRecipeId(byTitle: recipe.title) else {
            throw UserDataServiceError.recipeNotFound
        }
        try await dbInterface.recordCookingSession(
            recipeId: recipeId,
            date: Date(),
            duration: duration,
            rating: rating,
            rescuedIngredients: rescuedIngredients(from: recipe)
        )
        if recipe.missingIngredients?.isEmpty == true {
            defaults.set(
                defaults.integer(forKey: Keys.highMatchRecipesCookedCount) + 1,
                forKey: Keys.highMatchRecipesCookedCount
            )
        }
    }

    /// Derives the list of "rescued" ingredient names for a recipe.
    ///
    /// Rescued ingredients are those that were available but would otherwise have been wasted.
    /// Returns `nil` when the recipe has no missing-ingredient metadata.
    private func rescuedIngredients(from recipe: Recipe) -> [String]? {
        guard let missing = recipe.missingIngredients else { return nil }
        return RecipeMatchExplainer
            .ingredientAvailability(recipe: recipe, missingIngredientNames: missing)
            .rescuedIngredientNames
    }

    /// Returns past cooking sessions in reverse chronological order.
    /// - Parameter limit: Maximum number of sessions to return (default: 50).
    func getCookingSessions(limit: Int = UserDataServiceConstants.cookingSessionsLimit) async throws -> [CookingSession] {
        return try await dbInterface.getCookingSessions(limit: limit)
    }

    /// Returns the dates on which the user cooked something during the current calendar week.
    func getWeekCookingDates() async throws -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return []
        }
        let weekEnd = calendar.date(byAdding: .day, value: UserDataServiceConstants.weekDurationDays, to: weekStart) ?? now
        return try await dbInterface.getCookingSessionDates(from: weekStart, to: weekEnd)
    }

    /// Calculates the user's current consecutive-day cooking streak.
    ///
    /// The algorithm fetches all cooking session dates within the past 365 days, collapses
    /// them to unique calendar days, and walks backwards from today counting consecutive days.
    /// To avoid breaking a streak that was maintained yesterday but not yet today, the walk
    /// starts from yesterday when today has no cook session — i.e., the streak is preserved
    /// until midnight of the day after the last cook.
    /// - Returns: Number of consecutive days the user has cooked, or `0` if no sessions exist.
    func currentStreak() async throws -> Int {
        let calendar = Calendar.current
        let now = Date()
        let lookbackStart = calendar.date(byAdding: .day, value: -UserDataServiceConstants.streakLookbackDays, to: now) ?? now
        let dates = try await dbInterface.getCookingSessionDates(from: lookbackStart, to: now)

        let uniqueDays = Set(dates.map { calendar.startOfDay(for: $0) }).sorted(by: >)
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var expectedDay = calendar.startOfDay(for: now)

        if uniqueDays.first != expectedDay {
            expectedDay = calendar.date(byAdding: .day, value: UserDataServiceConstants.singleDayOffset, to: expectedDay)!
        }

        for day in uniqueDays {
            if day == expectedDay {
                streak += 1
                expectedDay = calendar.date(byAdding: .day, value: UserDataServiceConstants.singleDayOffset, to: expectedDay)!
            } else if day < expectedDay {
                break
            }
        }
        return streak
    }

    /// Returns the total time the user has spent cooking across all sessions.
    func totalCookingTime() async throws -> TimeInterval {
        return try await dbInterface.getTotalCookingDuration()
    }

    /// Returns the total number of cooking sessions recorded (all-time).
    func recipesCooked() async throws -> Int {
        return try await dbInterface.getCookingSessionCount()
    }

    // MARK: - User-Created Recipes

    /// Returns all recipes created by the user.
    func getUserRecipes() async throws -> [Recipe] {
        return try await dbInterface.getUserCreatedRecipes()
    }

    /// Returns the number of recipes the user has created.
    func getUserRecipeCount() async throws -> Int {
        return try await dbInterface.getUserCreatedRecipeCount()
    }

    /// Returns the count of distinct ingredients the user has cooked with (all-time).
    func getDistinctIngredientsUsedCount() async throws -> Int {
        return try await dbInterface.getDistinctCookedIngredientCount()
    }

    /// Returns the number of recipes cooked during the current calendar month.
    func monthlyRecipesCooked() async throws -> Int {
        let (monthStart, monthEnd) = currentMonthRange()
        return try await dbInterface.getCookingSessionCount(from: monthStart, to: monthEnd)
    }

    /// Returns the count of distinct ingredients used in sessions during the current calendar month.
    func monthlyIngredientsRescued() async throws -> Int {
        let (monthStart, monthEnd) = currentMonthRange()
        return try await dbInterface.getDistinctCookedIngredientCount(from: monthStart, to: monthEnd)
    }

    /// Returns a premium monthly cooking summary with an approximate savings estimate.
    func monthlyCookingInsights() async throws -> MonthlyCookingInsights {
        let mealsCooked = try await monthlyRecipesCooked()
        let uniqueIngredientsUsed = try await monthlyIngredientsRescued()
        // Origin: prod/tickets/TICKET_GRAPH.md T-023 / D-033 use 14 meals ~= $56 saved, so v1 estimates $4 per cooked meal.
        let estimatedSavingsPerCookedMeal = 4
        return MonthlyCookingInsights(
            mealsCooked: mealsCooked,
            uniqueIngredientsUsed: uniqueIngredientsUsed,
            estimatedSavingsAmount: mealsCooked * estimatedSavingsPerCookedMeal,
            currencyCode: "USD",
            isApproximate: true
        )
    }

    /// Returns the number of times the user has cooked a recipe with no missing ingredients.
    ///
    /// Persisted in `UserDefaults` and incremented in `markAsCooked` when `missingIngredients`
    /// is empty. Used by the achievement system.
    func getHighMatchRecipesCookedCount() -> Int {
        defaults.integer(forKey: Keys.highMatchRecipesCookedCount)
    }

    /// Returns the start and end `Date` for the current calendar month.
    private func currentMonthRange() -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        return (monthStart, monthEnd)
    }

    /// Returns the user's persisted theme preference, defaulting to `.system` when unset.
    func getThemePreference() -> ThemePreference {
        ThemePreference.from(rawValue: defaults.string(forKey: Keys.themePreference))
    }

    /// Persists the user's theme preference to `UserDefaults`.
    /// - Parameter themePreference: The theme to apply app-wide.
    func setThemePreference(_ themePreference: ThemePreference) {
        defaults.set(themePreference.rawValue, forKey: Keys.themePreference)
    }

    /// Inserts a new user-created recipe into the database.
    /// - Parameter recipe: The recipe to save.
    func saveUserRecipe(_ recipe: Recipe) async throws {
        try await dbInterface.insertUserRecipe(recipe)
    }

    /// Updates an existing user-created recipe in the database.
    /// - Parameter recipe: The recipe with updated fields.
    func updateUserRecipe(_ recipe: Recipe) async throws {
        try await dbInterface.updateUserRecipe(recipe)
    }

    /// Deletes a user-created recipe from the database.
    /// - Parameter recipe: The recipe to delete.
    /// - Throws: `UserDataServiceError.recipeNotFound` if the recipe cannot be located by title.
    func deleteUserRecipe(recipe: Recipe) async throws {
        guard let recipeId = try await getRecipeId(byTitle: recipe.title) else {
            throw UserDataServiceError.recipeNotFound
        }
        try await dbInterface.deleteUserRecipe(recipeId: recipeId)
    }

    // MARK: - Data Management

    /// Clears all recent data (ingredients, recipes, searches)
    func clearRecentData() async throws {
        try await dbInterface.clearRecentData()
    }

    /// Clears all favorite recipes
    func clearFavorites() async throws {
        try await dbInterface.clearFavorites()
    }
    
    // MARK: - Private Helpers

    /// Gets the database ID for a recipe by its title
    /// - Parameter title: The recipe title
    /// - Returns: The database ID if found, nil otherwise
    private func getRecipeId(byTitle title: String) async throws -> Int? {
        // This requires direct database access - we need to query the recipes table
        // Since DBInterfaceProtocol doesn't expose this, we need to cast to DBInterface
        return try await dbInterface.getRecipeId(byTitle: title)
    }
}

// MARK: - Error Types

/// Errors that can be thrown by `UserDataService` operations.
enum UserDataServiceError: Error, LocalizedError {
    /// The requested recipe could not be found in the database by its title.
    case recipeNotFound

    var errorDescription: String? {
        switch self {
        case .recipeNotFound:
            return "Recipe not found in database"
        }
    }
}
