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
            let recipes = try dbInterface.getRecipes(byIngredients: ingredients)
            
            if recipes.isEmpty {
                throw RecipeSourceError.noRecipesFound
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
