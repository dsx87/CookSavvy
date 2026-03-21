//
//  MockUserDataService.swift
//  CookSavvyTests
//

import Foundation
@testable import CookSavvy

final class MockUserDataService: UserDataServiceProtocol {

    // MARK: - Configurable return values

    var stubbedRecentIngredients: [Ingredient] = []
    var stubbedPopularIngredients: [Ingredient] = []
    var stubbedRecentRecipes: [Recipe] = []
    var stubbedFavorites: [Recipe] = []
    var stubbedSavedRecipes: [Recipe] = []
    var stubbedIsFavorite: Bool = false
    var stubbedToggleFavorite: Bool = false
    var stubbedRecentSearches: [[Ingredient]] = []
    var stubbedCookingSessions: [CookingSession] = []
    var stubbedWeekCookingDates: [Date] = []
    var stubbedCurrentStreak: Int = 0
    var stubbedTotalCookingTime: TimeInterval = 0
    var stubbedRecipesCooked: Int = 0
    var stubbedUserRecipes: [Recipe] = []
    var stubbedUserRecipeCount: Int = 0
    var stubbedDistinctIngredientsUsedCount: Int = 0
    var stubbedMonthlyRecipesCooked: Int = 0
    var stubbedMonthlyIngredientsRescued: Int = 0
    var stubbedThemePreference: ThemePreference = .system
    var stubbedEnabledSources: Set<RecipeSourceType> = [.offline]
    var stubbedIsSourceEnabled: Bool = true
    var stubbedToggleSource: Bool = true
    var shouldThrow: Error?

    // MARK: - Call tracking

    var markAsCookedCalls: [(recipe: Recipe, duration: TimeInterval?, rating: Int?)] = []
    var toggleFavoriteCalls: [Recipe] = []
    var recordedRecipeViews: [Recipe] = []
    var savedUserRecipes: [Recipe] = []
    var updatedUserRecipes: [Recipe] = []
    var deletedUserRecipes: [Recipe] = []
    var recordedIngredientUsages: [[Ingredient]] = []
    var recordedSearches: [[Ingredient]] = []
    var setThemePreferenceCalls: [ThemePreference] = []
    var setEnabledSourcesCalls: [Set<RecipeSourceType>] = []
    var clearRecentDataCallCount = 0
    var clearFavoritesCallCount = 0

    // MARK: - UserDataServiceProtocol

    func getRecentIngredients(limit: Int) async throws -> [Ingredient] {
        if let error = shouldThrow { throw error }
        return stubbedRecentIngredients
    }

    func getPopularIngredients(limit: Int) async throws -> [Ingredient] {
        if let error = shouldThrow { throw error }
        return stubbedPopularIngredients
    }

    func recordIngredientUsage(_ ingredients: [Ingredient]) async throws {
        if let error = shouldThrow { throw error }
        recordedIngredientUsages.append(ingredients)
    }

    func getRecentRecipes(limit: Int) async throws -> [Recipe] {
        if let error = shouldThrow { throw error }
        return stubbedRecentRecipes
    }

    func recordRecipeView(_ recipe: Recipe) async throws {
        if let error = shouldThrow { throw error }
        recordedRecipeViews.append(recipe)
    }

    func getFavorites() async throws -> [Recipe] {
        if let error = shouldThrow { throw error }
        return stubbedFavorites
    }

    func getSavedRecipes() async throws -> [Recipe] {
        if let error = shouldThrow { throw error }
        return stubbedSavedRecipes
    }

    func toggleFavorite(_ recipe: Recipe) async throws -> Bool {
        if let error = shouldThrow { throw error }
        toggleFavoriteCalls.append(recipe)
        return stubbedToggleFavorite
    }

    func isFavorite(_ recipe: Recipe) async throws -> Bool {
        if let error = shouldThrow { throw error }
        return stubbedIsFavorite
    }

    func getRecentSearches(limit: Int) async throws -> [[Ingredient]] {
        if let error = shouldThrow { throw error }
        return stubbedRecentSearches
    }

    func recordSearch(ingredients: [Ingredient]) async throws {
        if let error = shouldThrow { throw error }
        recordedSearches.append(ingredients)
    }

    func markAsCooked(recipe: Recipe, duration: TimeInterval?, rating: Int?) async throws {
        if let error = shouldThrow { throw error }
        markAsCookedCalls.append((recipe: recipe, duration: duration, rating: rating))
    }

    func getCookingSessions(limit: Int) async throws -> [CookingSession] {
        if let error = shouldThrow { throw error }
        return stubbedCookingSessions
    }

    func getWeekCookingDates() async throws -> [Date] {
        if let error = shouldThrow { throw error }
        return stubbedWeekCookingDates
    }

    func currentStreak() async throws -> Int {
        if let error = shouldThrow { throw error }
        return stubbedCurrentStreak
    }

    func totalCookingTime() async throws -> TimeInterval {
        if let error = shouldThrow { throw error }
        return stubbedTotalCookingTime
    }

    func recipesCooked() async throws -> Int {
        if let error = shouldThrow { throw error }
        return stubbedRecipesCooked
    }

    func getUserRecipes() async throws -> [Recipe] {
        if let error = shouldThrow { throw error }
        return stubbedUserRecipes
    }

    func getUserRecipeCount() async throws -> Int {
        if let error = shouldThrow { throw error }
        return stubbedUserRecipeCount
    }

    func getDistinctIngredientsUsedCount() async throws -> Int {
        if let error = shouldThrow { throw error }
        return stubbedDistinctIngredientsUsedCount
    }

    func monthlyRecipesCooked() async throws -> Int {
        if let error = shouldThrow { throw error }
        return stubbedMonthlyRecipesCooked
    }

    func monthlyIngredientsRescued() async throws -> Int {
        if let error = shouldThrow { throw error }
        return stubbedMonthlyIngredientsRescued
    }

    func getThemePreference() -> ThemePreference {
        stubbedThemePreference
    }

    func setThemePreference(_ themePreference: ThemePreference) {
        setThemePreferenceCalls.append(themePreference)
        stubbedThemePreference = themePreference
    }

    func saveUserRecipe(_ recipe: Recipe) async throws {
        if let error = shouldThrow { throw error }
        savedUserRecipes.append(recipe)
    }

    func updateUserRecipe(_ recipe: Recipe) async throws {
        if let error = shouldThrow { throw error }
        updatedUserRecipes.append(recipe)
    }

    func deleteUserRecipe(recipe: Recipe) async throws {
        if let error = shouldThrow { throw error }
        deletedUserRecipes.append(recipe)
    }

    func clearRecentData() async throws {
        if let error = shouldThrow { throw error }
        clearRecentDataCallCount += 1
    }

    func clearFavorites() async throws {
        if let error = shouldThrow { throw error }
        clearFavoritesCallCount += 1
    }

    func getEnabledSources() -> Set<RecipeSourceType> {
        stubbedEnabledSources
    }

    func setEnabledSources(_ sources: Set<RecipeSourceType>) {
        setEnabledSourcesCalls.append(sources)
        stubbedEnabledSources = sources
    }

    func isSourceEnabled(_ source: RecipeSourceType) -> Bool {
        stubbedIsSourceEnabled
    }

    func toggleSource(_ source: RecipeSourceType) -> Bool {
        stubbedToggleSource
    }
}
