import Foundation

/// Defines the public interface for the ingredient catalog and search service.
///
/// The ingredient catalog is seeded into the database by `DataImportService` during recipe
/// import. Conforming types expose `ensureIngredientsLoaded()` as a readiness gate,
/// FTS5-backed search, category browsing, and exact-name lookup. The protocol allows
/// `IngredientsService` to be replaced with a mock in tests and DEBUG builds.
protocol IngredientsServiceProtocol: AnyObject {
    /// Marks the service as ready; the ingredient catalog is seeded by `DataImportService`.
    func ensureIngredientsLoaded() async throws
    /// Returns ingredient names matching `query` using FTS5 prefix search, up to `limit` results.
    func searchIngredients(matching query: String, limit: Int) async throws -> [String]
    /// Returns full `Ingredient` objects matching `query` using FTS5 prefix search, up to `limit` results.
    func searchFullIngredients(matching query: String, limit: Int) async throws -> [Ingredient]
    /// Returns the `Ingredient` whose name exactly matches `name`, or `nil` if not found.
    func getIngredient(byName name: String) async throws -> Ingredient?
    /// Returns ingredients, optionally filtered by `category`, up to `limit` results.
    func getAllIngredients(category: IngredientCategory?, limit: Int) async throws -> [Ingredient]
    /// Returns the `IngredientCategory` values that have at least one ingredient in the database.
    func getCategories() async throws -> [IngredientCategory]
}

/// Default-parameter overloads so call sites can omit `limit` for the common case.
/// Default values must stay in sync with `IngredientsServiceConstants`.
extension IngredientsServiceProtocol {
    // Defaults must stay in sync with IngredientsService.Constants
    /// Searches ingredient names using FTS5, returning up to 50 results.
    func searchIngredients(matching query: String) async throws -> [String] {
        try await searchIngredients(matching: query, limit: 50)
    }

    /// Searches full `Ingredient` objects using FTS5, returning up to 50 results.
    func searchFullIngredients(matching query: String) async throws -> [Ingredient] {
        try await searchFullIngredients(matching: query, limit: 50)
    }

    /// Returns all ingredients (or those in `category`), up to 100 results.
    func getAllIngredients(category: IngredientCategory? = nil) async throws -> [Ingredient] {
        try await getAllIngredients(category: category, limit: 100)
    }
}
