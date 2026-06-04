//
//  IngredientsService.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Internal constants used by `IngredientsService` to avoid magic values.
private enum IngredientsServiceConstants {
    static let defaultSearchLimit = 50
    static let defaultCategoryLimit = 100
}

/// Manages the ingredient catalog and user ingredient history.
///
/// The ingredient catalog is seeded into the database by `DataImportService` during recipe
/// import — `IngredientsService` does not import data itself. `ensureIngredientsLoaded()`
/// is a lightweight gate that marks the service ready; it is a no-op if the catalog has
/// already been confirmed present. Subsequent searches leverage GRDB's FTS5 full-text index
/// for fast prefix-matching. The service also provides category browsing — note that
/// `IngredientCategory` is a computed property derived from the raw `foodGroup` string stored
/// in the database, so category-based queries require an intermediate mapping step through a
/// proxy `Ingredient`.
final class IngredientsService: IngredientsServiceProtocol {

    // MARK: - Properties

    /// Database interface used for all ingredient read/write operations.
    private let dbInterface: IngredientStoreProtocol

    /// Tracks whether the service has been marked ready after the initial check.
    private var isImported: Bool = false

    // MARK: - Initialization

    /// Initializes the ingredients service.
    /// - Parameter dbInterface: Database interface for storing and retrieving ingredients.
    init(dbInterface: IngredientStoreProtocol) {
        self.dbInterface = dbInterface
    }

    #if DEBUG
    /// Convenience initializer for DEBUG builds that creates its own `DBInterface`.
    /// - Throws: Any error thrown by `DBInterface` initialization.
    convenience init() throws {
        let dbInterface = try DBInterface()
        self.init(dbInterface: dbInterface)
    }
    #endif

    // MARK: - Public Methods

    /// Marks the service as ready. The ingredient catalog is seeded by `DataImportService`
    /// during recipe import; this method is a no-op gate that prevents redundant DB probes
    /// on subsequent calls to search and retrieval methods.
    func ensureIngredientsLoaded() async throws {
        isImported = true
    }

    /// Searches for ingredients matching the provided query
    /// - Parameters:
    ///   - query: Search text to match against ingredient names
    ///   - limit: Maximum number of results to return (default: 50)
    /// - Returns: Array of matching ingredient names
    /// - Throws: IngredientsServiceError if search fails
    func searchIngredients(matching query: String, limit: Int = IngredientsServiceConstants.defaultSearchLimit) async throws -> [String] {
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
}

// MARK: - Error Types

/// Errors that can occur during ingredient service operations.
enum IngredientsServiceError: Error, LocalizedError {
    /// An FTS5 search query against the ingredients table failed.
    case searchFailed(Error)
    /// A lookup by exact ingredient name failed.
    case retrievalFailed(Error)
    /// A general database operation (e.g. fetching food groups) failed.
    case databaseError(Error)

    var errorDescription: String? {
        switch self {
        case .searchFailed(let error):
            return "Failed to search ingredients: \(error.localizedDescription)"
        case .retrievalFailed(let error):
            return "Failed to retrieve ingredient: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}
