//
//  RecipeService.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Main service for managing recipe operations across different sources
final class RecipeService: RecipeServiceProtocol {
    
    // MARK: - Properties
    
    /// Available recipe sources
    private var sources: [RecipeSourceType: RecipeSourceProtocol]
    
    /// Database interface for storing fetched recipes
    private let dbInterface: DBInterfaceProtocol
    
    /// Flag to control whether fetched recipes should be stored in DB
    private let shouldStoreRecipes: Bool
    
    // MARK: - Initialization
    
    /// Initializes the recipe service with custom sources and database
    /// - Parameters:
    ///   - dbInterface: Database interface for storing recipes
    ///   - sources: Dictionary of available recipe sources
    ///   - shouldStoreRecipes: Whether to automatically store fetched recipes in DB (default: true)
    init(
        dbInterface: DBInterfaceProtocol,
        sources: [RecipeSourceType: RecipeSourceProtocol],
        shouldStoreRecipes: Bool = true
    ) {
        self.dbInterface = dbInterface
        self.sources = sources
        self.shouldStoreRecipes = shouldStoreRecipes
    }
    
    /// Convenience initializer with default sources
    /// - Parameters:
    ///   - dbInterface: Database interface for storing recipes (default: new DBInterface)
    ///   - shouldStoreRecipes: Whether to automatically store fetched recipes in DB (default: true)
    convenience init(
        dbInterface: DBInterfaceProtocol = DBInterface(),
        shouldStoreRecipes: Bool = true
    ) {
        let offlineSource = OfflineRecipeSource(dbInterface: dbInterface)
        let onlineSource = OnlineRecipeSource()
        let aiSource = AIRecipeSource()
        
        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .offline: offlineSource,
            .online: onlineSource,
            .ai: aiSource
        ]
        
        self.init(
            dbInterface: dbInterface,
            sources: sources,
            shouldStoreRecipes: shouldStoreRecipes
        )
    }
    
    // MARK: - Public Methods
    
    /// Fetches recipes from a specific source
    /// - Parameters:
    ///   - ingredients: List of ingredients to search for
    ///   - sourceType: The specific source to use
    /// - Returns: Array of matching recipes
    /// - Throws: RecipeSourceError if fetching fails
    func getRecipes(for ingredients: [Ingredient], from sourceType: RecipeSourceType) async throws -> [Recipe] {
        guard let source = sources[sourceType] else {
            throw RecipeSourceError.sourceUnavailable(sourceType)
        }
        
        guard await source.isAvailable() else {
            throw RecipeSourceError.sourceUnavailable(sourceType)
        }
        
        var recipes = try await source.fetchRecipes(for: ingredients)
        for i in recipes.indices { recipes[i].source = sourceType }
        
        // Store recipes in database if enabled (skip offline — already in DB)
        if shouldStoreRecipes && sourceType != .offline && !recipes.isEmpty {
            try storeRecipes(recipes)
        }
        
        return recipes
    }
    
    /// Checks if a specific source is available
    /// - Parameter sourceType: The source type to check
    /// - Returns: True if the source is available, false otherwise
    func isSourceAvailable(_ sourceType: RecipeSourceType) async -> Bool {
        guard let source = sources[sourceType] else {
            return false
        }
        return await source.isAvailable()
    }
    
    /// Gets all available source types
    /// - Returns: Array of available source types
    func getAvailableSources() async -> [RecipeSourceType] {
        var available: [RecipeSourceType] = []
        
        for sourceType in RecipeSourceType.allCases {
            if await isSourceAvailable(sourceType) {
                available.append(sourceType)
            }
        }
        
        return available
    }
    
    /// Manually stores recipes in the database
    /// - Parameter recipes: Recipes to store
    /// - Throws: RecipeSourceError if storage fails
    func storeRecipes(_ recipes: [Recipe]) throws {
        guard !recipes.isEmpty else { return }
        
        do {
            try dbInterface.insertRecipes(recipes)
        } catch {
            throw RecipeSourceError.databaseError(error)
        }
    }
    
    /// Retrieves recipes directly from the database (bypassing sources)
    /// - Parameter ingredients: List of ingredients to search for
    /// - Returns: Array of matching recipes from the database
    /// - Throws: RecipeSourceError if retrieval fails
    func getStoredRecipes(for ingredients: [Ingredient]) throws -> [Recipe] {
        do {
            return try dbInterface.getRecipes(byIngredients: ingredients, offset: 0, limit: 20)
        } catch {
            throw RecipeSourceError.databaseError(error)
        }
    }
    
    /// Fetches recipes from multiple sources and merges results
    /// - Parameters:
    ///   - ingredients: List of ingredients to search for
    ///   - sourceTypes: Set of sources to query
    /// - Returns: Array of merged recipes from all sources
    func getRecipes(for ingredients: [Ingredient], from sourceTypes: Set<RecipeSourceType>) async throws -> [Recipe] {
        var allRecipes: [Recipe] = []
        var seenTitles: Set<String> = []
        
        for sourceType in sourceTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let source = sources[sourceType],
                  await source.isAvailable() else {
                continue
            }
            
            do {
                let recipes = try await source.fetchRecipes(for: ingredients)
                for var recipe in recipes {
                    if !seenTitles.contains(recipe.title) {
                        seenTitles.insert(recipe.title)
                        recipe.source = sourceType
                        allRecipes.append(recipe)
                    }
                }
            } catch {
                print("⚠️ Source \(sourceType) failed: \(error)")
            }
        }
        
        if shouldStoreRecipes {
            let nonOfflineRecipes = allRecipes.filter { $0.source != .offline }
            if !nonOfflineRecipes.isEmpty {
                try storeRecipes(nonOfflineRecipes)
            }
        }
        
        return allRecipes
    }
}
