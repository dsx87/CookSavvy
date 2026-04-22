//
//  IngredientsService.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Internal constants used by `IngredientsService` to avoid magic values.
private enum IngredientsServiceConstants {
    static let defaultFileName = "Food"
    static let defaultFileExtension = "json"
    static let defaultSearchLimit = 50
    static let defaultCategoryLimit = 100
    static let populationProbe = "a"
    static let populationProbeLimit = 1
}

/// Manages the ingredient catalog and user ingredient history.
///
/// On first use, imports the ingredient catalog from a bundled JSON file into the SQLite database
/// via `DBInterface`. Subsequent searches leverage GRDB's FTS5 full-text index for fast
/// prefix-matching. The service also provides category browsing — note that `IngredientCategory`
/// is a computed property derived from the raw `foodGroup` string stored in the database, so
/// category-based queries require an intermediate mapping step through a proxy `Ingredient`.
final class IngredientsService: IngredientsServiceProtocol {
    
    // MARK: - Properties
    
    /// Database interface used for all ingredient read/write operations.
    private let dbInterface: DBInterfaceProtocol
    /// Name of the bundled JSON file containing the ingredient catalog.
    private let ingredientsFileName: String
    /// File extension of the bundled ingredient catalog file.
    private let ingredientsFileExtension: String
    
    /// Tracks whether ingredients have been imported
    private var isImported: Bool = false
    
    // MARK: - Initialization
    
    /// Initializes the ingredients service
    /// - Parameters:
    ///   - dbInterface: Database interface for storing and retrieving ingredients
    ///   - ingredientsFileName: Name of the JSON file containing ingredients (default: "Food")
    ///   - ingredientsFileExtension: File extension (default: "json")
    init(
        dbInterface: DBInterfaceProtocol,
        ingredientsFileName: String = IngredientsServiceConstants.defaultFileName,
        ingredientsFileExtension: String = IngredientsServiceConstants.defaultFileExtension
    ) {
        self.dbInterface = dbInterface
        self.ingredientsFileName = ingredientsFileName
        self.ingredientsFileExtension = ingredientsFileExtension
    }

    #if DEBUG
    /// Convenience initializer for DEBUG builds that creates its own `DBInterface`.
    /// - Parameters:
    ///   - ingredientsFileName: Name of the bundled JSON ingredient catalog (default: "Food").
    ///   - ingredientsFileExtension: File extension of the catalog (default: "json").
    /// - Throws: Any error thrown by `DBInterface` initialization.
    convenience init(
        ingredientsFileName: String = IngredientsServiceConstants.defaultFileName,
        ingredientsFileExtension: String = IngredientsServiceConstants.defaultFileExtension
    ) throws {
        let dbInterface = try DBInterface()
        self.init(
            dbInterface: dbInterface,
            ingredientsFileName: ingredientsFileName,
            ingredientsFileExtension: ingredientsFileExtension
        )
    }
    #endif
    
    // MARK: - Public Methods
    
    /// Ensures ingredients are loaded into the database
    /// This should be called when the app starts
    /// - Throws: IngredientsServiceError if import fails
    func ensureIngredientsLoaded() async throws {
        // Check if ingredients already exist in database
        let hasIngredients = try await checkIngredientsExist()
        
        if !hasIngredients {
            try await importIngredients()
        }
        
        isImported = true
    }
    
    /// Searches for ingredients matching the provided query
    /// - Parameters:
    ///   - query: Search text to match against ingredient names
    ///   - limit: Maximum number of results to return (default: 50)
    /// - Returns: Array of matching ingredient names
    /// - Throws: IngredientsServiceError if search fails
    func searchIngredients(matching query: String, limit: Int = IngredientsServiceConstants.defaultSearchLimit) async throws -> [String] {
        // Ensure ingredients are loaded before searching
        if !isImported {
            try await ensureIngredientsLoaded()
        }
        
        guard !query.isEmpty else { return [] }
        
        do {
            let ingredients = try dbInterface.searchIngredients(matching: query, limit: limit)
            return ingredients.map { $0.name }
        } catch {
            throw IngredientsServiceError.searchFailed(error)
        }
    }
    
    /// Searches for full ingredient objects matching the provided query
    /// - Parameters:
    ///   - query: Search text to match against ingredient names
    ///   - limit: Maximum number of results to return (default: 50)
    /// - Returns: Array of matching ingredients
    /// - Throws: IngredientsServiceError if search fails
    func searchFullIngredients(matching query: String, limit: Int = IngredientsServiceConstants.defaultSearchLimit) async throws -> [Ingredient] {
        // Ensure ingredients are loaded before searching
        if !isImported {
            try await ensureIngredientsLoaded()
        }
        
        guard !query.isEmpty else { return [] }
        
        do {
            return try dbInterface.searchIngredients(matching: query, limit: limit)
        } catch {
            throw IngredientsServiceError.searchFailed(error)
        }
    }
    
    /// Gets a specific ingredient by exact name
    /// - Parameter name: Exact name of the ingredient
    /// - Returns: The ingredient if found, nil otherwise
    /// - Throws: IngredientsServiceError if retrieval fails
    func getIngredient(byName name: String) async throws -> Ingredient? {
        // Ensure ingredients are loaded before searching
        if !isImported {
            try await ensureIngredientsLoaded()
        }
        
        do {
            let results = try dbInterface.getIngredients(byName: name)
            return results.first
        } catch {
            throw IngredientsServiceError.retrievalFailed(error)
        }
    }
    
    /// Returns ingredients, optionally filtered by category, up to `limit` results.
    ///
    /// Filtering by `IngredientCategory` requires a two-step mapping because the database
    /// stores raw `foodGroup` strings rather than a typed category column. All distinct food
    /// group strings are fetched first; each is mapped to an `IngredientCategory` by constructing
    /// a throwaway `Ingredient` and reading its computed `.category` property. Only groups that
    /// match the requested category are then queried for actual ingredients.
    ///
    /// - Parameters:
    ///   - category: If provided, only ingredients in this category are returned. Pass `nil` for all ingredients.
    ///   - limit: Maximum number of ingredients to return (default: 100).
    /// - Returns: Array of matching ingredients.
    /// - Throws: `IngredientsServiceError.searchFailed` if the database query fails.
    func getAllIngredients(category: IngredientCategory? = nil, limit: Int = IngredientsServiceConstants.defaultCategoryLimit) async throws -> [Ingredient] {
        if !isImported {
            try await ensureIngredientsLoaded()
        }

        do {
            if let category {
                let groups = try dbInterface.getDistinctFoodGroups()
                let matchingGroups = groups.filter { group in
                    let testIngredient = Ingredient(name: "", description: nil, pictureFileName: nil, foodGroup: group, foodSubgroup: nil)
                    return testIngredient.category == category
                }
                var results: [Ingredient] = []
                for group in matchingGroups {
                    let batch = try dbInterface.getAllIngredients(inGroup: group, limit: limit - results.count)
                    results.append(contentsOf: batch)
                    if results.count >= limit { break }
                }
                return Array(results.prefix(limit))
            } else {
                return try dbInterface.getAllIngredients(inGroup: nil, limit: limit)
            }
        } catch {
            throw IngredientsServiceError.searchFailed(error)
        }
    }

    /// Returns the set of `IngredientCategory` values that have at least one ingredient in the database.
    ///
    /// Like `getAllIngredients(category:limit:)`, this requires mapping raw `foodGroup` strings
    /// to `IngredientCategory` via a proxy `Ingredient`. Results are deduplicated with a `Set`
    /// and returned in the canonical order defined by `IngredientCategory.allCases`.
    ///
    /// - Returns: Categories present in the database, in canonical declaration order.
    /// - Throws: `IngredientsServiceError.databaseError` if the database query fails.
    func getCategories() async throws -> [IngredientCategory] {
        if !isImported {
            try await ensureIngredientsLoaded()
        }

        do {
            let groups = try dbInterface.getDistinctFoodGroups()
            let categories = Set(groups.map { group -> IngredientCategory in
                let testIngredient = Ingredient(name: "", description: nil, pictureFileName: nil, foodGroup: group, foodSubgroup: nil)
                return testIngredient.category
            })
            return IngredientCategory.allCases.filter { categories.contains($0) }
        } catch {
            throw IngredientsServiceError.databaseError(error)
        }
    }

    /// Forces a re-import of ingredients from the JSON file
    /// - Throws: IngredientsServiceError if import fails
    func forceReimport() async throws {
        try await importIngredients()
        isImported = true
    }
    
    // MARK: - Private Methods
    
    /// Checks if ingredients exist in the database
    /// - Returns: True if at least one ingredient exists, false otherwise
    private func checkIngredientsExist() async throws -> Bool {
        do {
            // Try to search for a common ingredient to check if DB is populated
            let results = try dbInterface.searchIngredients(
                matching: IngredientsServiceConstants.populationProbe,
                limit: IngredientsServiceConstants.populationProbeLimit
            )
            return !results.isEmpty
        } catch {
            throw IngredientsServiceError.databaseError(error)
        }
    }
    
    /// Imports ingredients from the JSON file into the database
    /// - Throws: IngredientsServiceError if import fails
    private func importIngredients() async throws {
        guard let fileURL = Bundle.main.url(
            forResource: ingredientsFileName,
            withExtension: ingredientsFileExtension
        ) else {
            throw IngredientsServiceError.fileNotFound(ingredientsFileName)
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let ingredients = try JSONDecoder().decode([Ingredient].self, from: data)
            
            guard !ingredients.isEmpty else {
                throw IngredientsServiceError.emptyFile
            }
            
            try dbInterface.insertIngredients(ingredients)
        } catch let error as IngredientsServiceError {
            throw error
        } catch {
            throw IngredientsServiceError.importFailed(error)
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during ingredient service operations.
enum IngredientsServiceError: Error, LocalizedError {
    /// The bundled ingredient catalog file could not be located in the app bundle.
    case fileNotFound(String)
    /// The ingredient catalog file was found but contained no ingredient entries.
    case emptyFile
    /// Decoding or writing the ingredient catalog to the database failed.
    case importFailed(Error)
    /// An FTS5 search query against the ingredients table failed.
    case searchFailed(Error)
    /// A lookup by exact ingredient name failed.
    case retrievalFailed(Error)
    /// A general database operation (e.g. fetching food groups) failed.
    case databaseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Ingredients file '\(fileName)' not found in bundle"
        case .emptyFile:
            return "Ingredients file is empty"
        case .importFailed(let error):
            return "Failed to import ingredients: \(error.localizedDescription)"
        case .searchFailed(let error):
            return "Failed to search ingredients: \(error.localizedDescription)"
        case .retrievalFailed(let error):
            return "Failed to retrieve ingredient: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}
