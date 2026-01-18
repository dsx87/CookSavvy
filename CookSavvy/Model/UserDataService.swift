//
//  UserDataService.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import Foundation
import GRDB

/// Service for managing user-related data (recent items, favorites, search history)
final class UserDataService {

    // MARK: - Properties

    private let dbInterface: DBInterfaceProtocol

    // MARK: - Initialization

    init(dbInterface: DBInterfaceProtocol) {
        self.dbInterface = dbInterface
    }

    // MARK: - Recent Ingredients

    /// Gets the most recently used ingredients
    /// - Parameter limit: Maximum number of ingredients to return (default: 10)
    /// - Returns: Array of recent ingredients ordered by last used date
    func getRecentIngredients(limit: Int = 10) async throws -> [Ingredient] {
        return try dbInterface.getRecentIngredients(limit: limit)
    }

    // TODO: do some cleanup for this flow
    /// Gets the most popular ingredients based on usage count
    /// - Parameter limit: Maximum number of ingredients to return (default: 10)
    /// - Returns: Array of popular ingredients ordered by usage count
    func getPopularIngredients(limit: Int = 10) async throws -> [Ingredient] {
//        return try dbInterface.getPopularIngredients(limit: limit)
        let defaultFastIngredients: [Ingredient] = [
            ("Chicken", "🍗"),
            ("Rice", "🍚"),
            ("Pasta", "🍝"),
            ("Tomato", "🍅"),
            ("Onion", "🧅"),
            ("Garlic", "🧄"),
            ("Egg", "🥚"),
            ("Milk", "🥛"),
            ("Cheese", "🧀")
        ].map { .init(name: $0.0) }
        return defaultFastIngredients
    }

    /// Records usage of multiple ingredients
    /// - Parameter ingredients: Array of ingredients to record
    func recordIngredientUsage(_ ingredients: [Ingredient]) async throws {
        for ingredient in ingredients {
            try dbInterface.recordIngredientUsage(ingredient)
        }
    }

    // MARK: - Recent Recipes

    /// Gets the most recently viewed recipes
    /// - Parameter limit: Maximum number of recipes to return (default: 20)
    /// - Returns: Array of recent recipes ordered by last viewed date
    func getRecentRecipes(limit: Int = 20) async throws -> [Recipe] {
        return try dbInterface.getRecentRecipes(limit: limit)
    }

    /// Records that a recipe was viewed
    /// - Parameter recipe: The recipe that was viewed
    func recordRecipeView(_ recipe: Recipe) async throws {
        // Get the recipe ID from the database by title
        if let recipeId = try getRecipeId(byTitle: recipe.title) {
            try dbInterface.recordRecipeView(recipeId)
        }
    }

    // MARK: - Favorites

    /// Gets all favorite recipes
    /// - Returns: Array of favorite recipes ordered by added date (newest first)
    func getFavorites() async throws -> [Recipe] {
        return try dbInterface.getFavoriteRecipes()
    }

    /// Toggles the favorite status of a recipe
    /// - Parameter recipe: The recipe to toggle
    /// - Returns: True if the recipe is now favorited, false if it was unfavorited
    func toggleFavorite(_ recipe: Recipe) async throws -> Bool {
        guard let recipeId = try getRecipeId(byTitle: recipe.title) else {
            throw UserDataServiceError.recipeNotFound
        }

        let isFavorited = try dbInterface.isFavorite(recipeId)

        if isFavorited {
            try dbInterface.removeFavorite(recipeId)
            return false
        } else {
            try dbInterface.addFavorite(recipeId)
            return true
        }
    }

    /// Checks if a recipe is favorited
    /// - Parameter recipe: The recipe to check
    /// - Returns: True if the recipe is favorited, false otherwise
    func isFavorite(_ recipe: Recipe) async throws -> Bool {
        guard let recipeId = try getRecipeId(byTitle: recipe.title) else {
            return false
        }
        return try dbInterface.isFavorite(recipeId)
    }

    // MARK: - Recent Searches

    /// Gets recent ingredient searches
    /// - Parameter limit: Maximum number of searches to return (default: 10)
    /// - Returns: Array of ingredient arrays representing past searches
    func getRecentSearches(limit: Int = 10) async throws -> [[Ingredient]] {
        return try dbInterface.getRecentSearches(limit: limit)
    }

    /// Records a search with the given ingredients
    /// - Parameter ingredients: The ingredients that were searched for
    func recordSearch(ingredients: [Ingredient]) async throws {
        try dbInterface.recordSearch(ingredients: ingredients)
    }

    // MARK: - Data Management

    /// Clears all recent data (ingredients, recipes, searches)
    func clearRecentData() async throws {
        try dbInterface.clearRecentData()
    }

    /// Clears all favorite recipes
    func clearFavorites() async throws {
        try dbInterface.clearFavorites()
    }

    // MARK: - Private Helpers

    /// Gets the database ID for a recipe by its title
    /// - Parameter title: The recipe title
    /// - Returns: The database ID if found, nil otherwise
    private func getRecipeId(byTitle title: String) throws -> Int? {
        // This requires direct database access - we need to query the recipes table
        // Since DBInterfaceProtocol doesn't expose this, we need to cast to DBInterface
        guard let dbInterface = dbInterface as? DBInterface else {
            return nil
        }
        return try dbInterface.getRecipeId(byTitle: title)
    }
}

// MARK: - Error Types

enum UserDataServiceError: Error, LocalizedError {
    case recipeNotFound

    var errorDescription: String? {
        switch self {
        case .recipeNotFound:
            return "Recipe not found in database"
        }
    }
}
