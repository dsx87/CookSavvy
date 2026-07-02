//
//  IngredientsService.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Internal constants used by `IngredientsService` to avoid magic values.
/// `nonisolated` so the values can serve as default-parameter values on the `actor`'s methods
/// (a MainActor-isolated default value can't be read from an actor-isolated context).
private nonisolated enum IngredientsServiceConstants {
    static let defaultSearchLimit = 50
    static let defaultCategoryLimit = 100
    /// Upper bound for fetching the entire ingredient catalogue in one read so it can be categorised
    /// in memory. Comfortably exceeds the ~3.5k unique ingredients derived from the bundled dataset.
    static let allIngredientsLimit = 8000
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
///
/// **Isolation:** this is an `actor` (like `DBInterface` / `ImageService`), so *all* of its work runs
/// off the main actor — both the `await`s into the `DBInterface` actor and the continuation after each
/// `await` (pantry-staple filtering, catalogue classification) execute on this actor's executor rather
/// than the main thread. Its mutable state (`isImported`, `cachedCategorizedIngredients`) is serialised
/// by the actor. Callers (`DiscoverViewModel`, `DatabaseInitializationService`) `await` across the
/// boundary; every method's result type is `Sendable`.
actor IngredientsService: IngredientsServiceProtocol {

    // MARK: - Properties

    /// Database interface used for all ingredient read/write operations.
    private let dbInterface: IngredientStoreProtocol

    /// Tracks whether the service has been marked ready after the initial check.
    private var isImported: Bool = false

    /// Lazily-built, cached grouping of the full ingredient catalogue by ``IngredientCategory``.
    /// The dataset has no `food_group` data, so categories are classified from ingredient names; that
    /// classification is computed once on the cooperative pool (see `categorizedIngredients()`). The
    /// catalogue is static after import, so every subsequent category tap is a cheap dictionary lookup.
    private var cachedCategorizedIngredients: [IngredientCategory: [Ingredient]]?

    // MARK: - Initialization

    /// Initializes the ingredients service.
    /// - Parameter dbInterface: Database interface for storing and retrieving ingredients.
    init(dbInterface: IngredientStoreProtocol) {
        self.dbInterface = dbInterface
    }

    #if DEBUG
    /// Delegating initializer for DEBUG builds that creates its own `DBInterface`.
    /// (Actors don't use the `convenience` keyword; an init that delegates via `self.init` is a
    /// delegating initializer implicitly.)
    /// - Throws: Any error thrown by `DBInterface` initialization.
    init() throws {
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
            let ingredients = try await dbInterface.searchIngredients(matching: query, limit: limit)
            // Pantry staples (salt, pepper, dried spices, …) are never offered for selection.
            return PantryStaples.excludingStaples(ingredients).map { $0.name }
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
            let ingredients = try await dbInterface.searchIngredients(matching: query, limit: limit)
            // Pantry staples (salt, pepper, dried spices, …) are never offered for selection.
            return PantryStaples.excludingStaples(ingredients)
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
            let results = try await dbInterface.getIngredients(byName: name)
            return results.first
        } catch {
            throw IngredientsServiceError.retrievalFailed(error)
        }
    }

    /// Returns ingredients, optionally filtered by category, up to `limit` results.
    ///
    /// The bundled dataset carries no `food_group` data, so categories are derived from ingredient
    /// names via `Ingredient.category` (backed by `IngredientCategoryClassifier`). The catalogue is
    /// classified once off the main actor and cached as a category→ingredients map, so this call is a
    /// dictionary lookup (see `categorizedIngredients()`).
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
            guard let category else {
                let all = try await dbInterface.getAllIngredients(inGroup: nil, limit: limit)
                return PantryStaples.excludingStaples(all)
            }
            let grouped = try await categorizedIngredients()
            return Array((grouped[category] ?? []).prefix(limit))
        } catch {
            throw IngredientsServiceError.searchFailed(error)
        }
    }

    /// Returns the set of `IngredientCategory` values that have at least one ingredient in the
    /// catalogue, classified by name (the dataset has no `food_group` column).
    ///
    /// Returned in the canonical order defined by `IngredientCategory.allCases`.
    ///
    /// - Returns: Categories present in the catalogue, in canonical declaration order.
    /// - Throws: `IngredientsServiceError.databaseError` if the database query fails.
    func getCategories() async throws -> [IngredientCategory] {
        if !isImported {
            try await ensureIngredientsLoaded()
        }

        do {
            let grouped = try await categorizedIngredients()
            return IngredientCategory.allCases.filter { !(grouped[$0]?.isEmpty ?? true) }
        } catch {
            throw IngredientsServiceError.databaseError(error)
        }
    }

    /// Fetches the full catalogue once and groups it by category, caching the result.
    ///
    /// This service is an `actor`, so this method already runs off the main actor. The staple
    /// filtering (~3.5k `PantryStaples.isStaple` checks) and the name-based classification via
    /// `IngredientCategoryClassifier` are pure CPU, so they run inside a `@concurrent` task on the
    /// cooperative pool — keeping the work off *both* the main actor and this actor's own executor, so
    /// a concurrent search isn't serialised behind it. The catalogue is static after import, so the
    /// grouped result is cached and reused for every category tap.
    private func categorizedIngredients() async throws -> [IngredientCategory: [Ingredient]] {
        if let cachedCategorizedIngredients {
            return cachedCategorizedIngredients
        }
        let all = try await dbInterface.getAllIngredients(inGroup: nil, limit: IngredientsServiceConstants.allIngredientsLimit)
        let grouped = await Task { @concurrent in
            // Drop pantry staples before grouping so they never surface under any category chip (e.g.
            // salt/dried spices are removed from `.spices`, leaving only herbs and condiments/sauces).
            let selectable = PantryStaples.excludingStaples(all)
            return Dictionary(grouping: selectable, by: { $0.category })
        }.value
        cachedCategorizedIngredients = grouped
        return grouped
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
