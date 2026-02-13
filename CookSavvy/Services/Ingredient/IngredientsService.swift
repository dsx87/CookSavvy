//
//  IngredientsService.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Service for managing ingredient operations including autocompletion
final class IngredientsService {
    
    // MARK: - Properties
    
    private let dbInterface: DBInterfaceProtocol
    private let ingredientsFileName: String
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
        dbInterface: DBInterfaceProtocol = DBInterface(),
        ingredientsFileName: String = "Food",
        ingredientsFileExtension: String = "json"
    ) {
        self.dbInterface = dbInterface
        self.ingredientsFileName = ingredientsFileName
        self.ingredientsFileExtension = ingredientsFileExtension
    }
    
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
    func searchIngredients(matching query: String, limit: Int = 50) async throws -> [String] {
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
    func searchFullIngredients(matching query: String, limit: Int = 50) async throws -> [Ingredient] {
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
    
    func getAllIngredients(category: IngredientCategory? = nil, limit: Int = 100) async throws -> [Ingredient] {
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
            let results = try dbInterface.searchIngredients(matching: "a", limit: 1)
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

/// Errors that can occur during ingredient service operations
enum IngredientsServiceError: Error, LocalizedError {
    case fileNotFound(String)
    case emptyFile
    case importFailed(Error)
    case searchFailed(Error)
    case retrievalFailed(Error)
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
