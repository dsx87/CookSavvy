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
    private let dbInterface: RecipeStoreProtocol

    /// Feature-scoped logger for recipe service events
    private let logger: any LoggerProtocol
    
    /// Flag to control whether fetched recipes should be stored in DB
    private let shouldStoreRecipes: Bool
    
    // MARK: - Initialization
    
    /// Initializes the recipe service with custom sources and database
    /// - Parameters:
    ///   - dbInterface: Database interface for storing recipes
    ///   - sources: Dictionary of available recipe sources
    ///   - shouldStoreRecipes: Whether to automatically store fetched recipes in DB (default: true)
    init(
        dbInterface: RecipeStoreProtocol,
        sources: [RecipeSourceType: RecipeSourceProtocol],
        logger: any LoggerProtocol = LoggingService().makeLogger(category: .recipeService),
        shouldStoreRecipes: Bool = true
    ) {
        self.dbInterface = dbInterface
        self.sources = sources
        self.logger = logger
        self.shouldStoreRecipes = shouldStoreRecipes
    }
    
    #if DEBUG
    /// Convenience initializer with default sources — DEBUG only (uses MockLLMProvider)
    /// - Parameters:
    ///   - dbInterface: Database interface for storing recipes (default: new DBInterface)
    ///   - shouldStoreRecipes: Whether to automatically store fetched recipes in DB (default: true)
    convenience init(
        dbInterface: RecipeStoreProtocol? = nil,
        shouldStoreRecipes: Bool = true
    ) throws {
        let resolvedDB: RecipeStoreProtocol
        if let dbInterface {
            resolvedDB = dbInterface
        } else {
            resolvedDB = try DBInterface()
        }

        let offlineSource = OfflineRecipeSource(dbInterface: resolvedDB)
        let onlineSource = OnlineRecipeSource()
        let aiSource = AIRecipeSource(aiService: AIService(visionProvider: MockLLMProvider()))

        let sources: [RecipeSourceType: RecipeSourceProtocol] = [
            .offline: offlineSource,
            .online: onlineSource,
            .ai: aiSource
        ]

        self.init(
            dbInterface: resolvedDB,
            sources: sources,
            logger: LoggingService().makeLogger(category: .recipeService),
            shouldStoreRecipes: shouldStoreRecipes
        )
    }
    #endif

    #if !DEBUG
    @available(*, unavailable, message: "The default RecipeService initializer uses MockLLMProvider and is DEBUG-only. Use init(dbInterface:sources:logger:shouldStoreRecipes:) in production.")
    /// Unavailable in non-DEBUG builds to prevent accidental Mock provider wiring in production.
    convenience init(
        dbInterface: RecipeStoreProtocol? = nil,
        shouldStoreRecipes: Bool = true
    ) throws {
        fatalError("DEBUG-only initializer")
    }
    #endif
    
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
    ///
    /// Sources are iterated in a stable order (sorted by `rawValue`). Results are deduplicated
    /// by title — the first source to return a given title wins. Per-source errors are caught
    /// and recorded in `hadSourceFailures` rather than propagating, so a single failing source
    /// never prevents results from other sources from being returned.
    /// - Parameters:
    ///   - ingredients: List of ingredients to search for
    ///   - sourceTypes: Set of sources to query
    /// - Returns: A tuple of the merged recipe list and whether any source encountered an error
    func getRecipes(for ingredients: [Ingredient], from sourceTypes: Set<RecipeSourceType>) async throws -> (recipes: [Recipe], hadSourceFailures: Bool) {
        var allRecipes: [Recipe] = []
        var seenTitles: Set<String> = []
        var hadSourceFailures = false

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
            } catch RecipeSourceError.noRecipesFound {
                // Source worked but found nothing — not a failure
            } catch {
                hadSourceFailures = true
                logger.warning("Source \(sourceType) failed: \(error)")
            }
        }

        if shouldStoreRecipes {
            let nonOfflineRecipes = allRecipes.filter { $0.source != .offline }
            if !nonOfflineRecipes.isEmpty {
                do {
                    try storeRecipes(nonOfflineRecipes)
                } catch {
                    logger.warning("Failed to cache recipes: \(error)")
                }
            }
        }

        return (allRecipes, hadSourceFailures)
    }

    func getAllRecipes(limit: Int) async throws -> [Recipe] {
        do {
            return try dbInterface.getAllRecipes(offset: 0, limit: limit)
        } catch {
            throw RecipeSourceError.databaseError(error)
        }
    }
}
