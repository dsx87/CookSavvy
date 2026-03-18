//
//  DBInterfaceProtocol.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/08/2025.
//

import Foundation

// MARK: - Database Error Types

enum DatabaseError: Error, LocalizedError {
    case recipeNotFound(String)
    case ingredientNotFound(String)
    case queryFailed(String, underlying: Error)
    case cacheError(String)
    case initializationError(Error)
    
    var errorDescription: String? {
        switch self {
        case .recipeNotFound(let title):
            return "Recipe '\(title)' not found"
        case .ingredientNotFound(let name):
            return "Ingredient '\(name)' not found"
        case .queryFailed(let query, let underlying):
            return "Database query failed: \(query). Underlying error: \(underlying.localizedDescription)"
        case .cacheError(let message):
            return "Cache error: \(message)"
        case .initializationError(let error):
            return "Database initialization failed: \(error.localizedDescription)"
        }
    }
}

protocol DBInterfaceProtocol {
    // MARK: - Ingredients
    func getIngredients(byName name:String) throws -> [Ingredient]
    func searchIngredients(matching query: String, limit: Int) throws -> [Ingredient]
    func insertIngredients(_ ingredients: [Ingredient]) throws
    func removeIngredients(_ ingredients: [Ingredient]) throws

    // MARK: - Recipes
    func getRecipes(byIngredients: [Ingredient], offset: Int, limit: Int) throws -> [Recipe]
    func getAllRecipes(offset: Int, limit: Int) throws -> [Recipe]
    func getRecipeId(byTitle title: String) throws -> Int?
    func insertRecipes(_ recipes: [Recipe]) throws
    func removeRecipes(_ recipes: [Recipe]) throws

    // MARK: - Recent Ingredients
    func getRecentIngredients(limit: Int) throws -> [Ingredient]
    func getPopularIngredients(limit: Int) throws -> [Ingredient]
    func recordIngredientUsage(_ ingredient: Ingredient) throws

    // MARK: - Recent Recipes
    func getRecentRecipes(limit: Int) throws -> [Recipe]
    func recordRecipeView(_ recipeId: Int) throws

    // MARK: - Favorites
    func getFavoriteRecipes() throws -> [Recipe]
    func addFavorite(_ recipeId: Int) throws
    func removeFavorite(_ recipeId: Int) throws
    func isFavorite(_ recipeId: Int) throws -> Bool

    // MARK: - Recent Searches
    func getRecentSearches(limit: Int) throws -> [[Ingredient]]
    func recordSearch(ingredients: [Ingredient]) throws

    // MARK: - Cooking Sessions
    func recordCookingSession(recipeId: Int, date: Date, duration: TimeInterval?, rating: Int?) throws
    func getCookingSessions(limit: Int) throws -> [CookingSession]
    func getCookingSessionDates(from startDate: Date, to endDate: Date) throws -> [Date]
    func getCookingSessionCount() throws -> Int
    func getTotalCookingDuration() throws -> TimeInterval

    // MARK: - User-Created Recipes
    func getUserCreatedRecipes() throws -> [Recipe]
    func getUserCreatedRecipeCount() throws -> Int
    func insertUserRecipe(_ recipe: Recipe) throws
    func updateUserRecipe(_ recipe: Recipe) throws
    func deleteUserRecipe(recipeId: Int) throws

    // MARK: - Ingredient Queries
    func getAllIngredients(inGroup foodGroup: String?, limit: Int) throws -> [Ingredient]
    func getDistinctFoodGroups() throws -> [String]

    // MARK: - Shopping List
    func getShoppingItems() throws -> [ShoppingItem]
    func addShoppingItems(_ names: [String], recipeTitle: String?) throws -> [ShoppingItem]
    func toggleShoppingItem(id: Int) throws -> Bool
    func removeShoppingItem(id: Int) throws
    func clearCheckedShoppingItems() throws

    // MARK: - Database Management
    func clearDatabase() throws
    func clearRecentData() throws
    func clearFavorites() throws

    // MARK: - Statistics
    func getRecipeCount() throws -> Int
    func getDistinctCookedIngredientCount() throws -> Int
}
