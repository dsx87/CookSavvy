//
//  OfflineRecipeSource.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Offline recipe source that fetches recipes from the local database
final class OfflineRecipeSource: RecipeSourceProtocol {
    
    private let dbInterface: DBInterfaceProtocol
    
    var sourceType: RecipeSourceType { .offline }
    
    /// Initializes the offline source with a database interface
    /// - Parameter dbInterface: Database interface to use for fetching recipes
    init(dbInterface: DBInterfaceProtocol) {
        self.dbInterface = dbInterface
    }
    
    /// Convenience initializer that creates a new DBInterface
    convenience init() {
        self.init(dbInterface: DBInterface())
    }
    
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
                let recipeIngredientNames = recipes[i].cleanedIngredients.map { $0.name.lowercased() }
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
    
    func isAvailable() async -> Bool {
        // Offline source is always available
        return true
    }
}
