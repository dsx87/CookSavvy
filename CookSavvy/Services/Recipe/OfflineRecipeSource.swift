//
//  OfflineRecipeSource.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Offline recipe source that fetches recipes from the local SQLite database.
///
/// Available to all subscription tiers. Always reports itself as available because
/// the local database is bundled with the app.
final class OfflineRecipeSource: RecipeSourceProtocol {

    /// Database interface used to query locally stored recipes.
    private let dbInterface: RecipeStoreProtocol

    /// Identifies this as the `.offline` source type.
    var sourceType: RecipeSourceType { .offline }
    
    /// Initializes the offline source with a database interface
    /// - Parameter dbInterface: Database interface to use for fetching recipes
    init(dbInterface: RecipeStoreProtocol) {
        self.dbInterface = dbInterface
    }
    
    /// Convenience initializer that creates a new DBInterface
    #if DEBUG
    /// DEBUG-only convenience initializer that constructs a fresh `DBInterface`.
    convenience init() throws {
        let dbInterface = try DBInterface()
        self.init(dbInterface: dbInterface)
    }
    #endif
    
    /// Fetches recipes from the local database that match the given ingredients and computes
    /// a `matchPercentage` for each result.
    ///
    /// The match percentage is calculated as:
    /// `matchedCount / totalIngredients * 100`, where a recipe ingredient is considered
    /// "matched" when either name contains the other (substring check), allowing partial
    /// name matches such as "cherry tomato" matching a search for "tomato".
    /// - Parameter ingredients: Ingredients the user has selected.
    /// - Returns: Matching recipes with `matchPercentage` populated.
    /// - Throws: `RecipeSourceError.noRecipesFound` if the ingredient list is empty or the
    ///   database returns no results; `RecipeSourceError.databaseError` on read failures.
    func fetchRecipes(for ingredients: [Ingredient]) async throws -> [Recipe] {
        guard !ingredients.isEmpty else {
            throw RecipeSourceError.noRecipesFound
        }
        
        do {
            var recipes = try dbInterface.getRecipes(byIngredients: ingredients, offset: 0, limit: 20)
            
            if recipes.isEmpty {
                throw RecipeSourceError.noRecipesFound
            }
            
            let searchNames = Set(ingredients.map { $0.name.lowercased() })
            for i in recipes.indices {
                let recipeIngredientNames = recipes[i].ingredients.map { $0.name.lowercased() }
                let totalIngredients = max(recipeIngredientNames.count, 1)
                let matchedCount = recipeIngredientNames.filter { name in
                    searchNames.contains(where: { name.contains($0) || $0.contains(name) })
                }.count
                recipes[i].matchPercentage = Double(matchedCount) / Double(totalIngredients) * 100
            }
            
            return recipes
        } catch let error as RecipeSourceError {
            throw error
        } catch {
            throw RecipeSourceError.databaseError(error)
        }
    }
    
    /// Always returns `true` — the offline database is bundled and unconditionally available.
    func isAvailable() async -> Bool {
        // Offline source is always available
        return true
    }
}
