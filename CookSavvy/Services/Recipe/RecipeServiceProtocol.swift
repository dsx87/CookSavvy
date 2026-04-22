import Foundation

/// Central interface for all recipe data operations across multiple sources.
///
/// Implementations coordinate fetching from offline, online, and AI sources, caching
/// non-offline results to the local database, and providing direct database access.
protocol RecipeServiceProtocol: AnyObject {

    /// Fetches recipes for the given ingredients from a single source.
    /// - Parameters:
    ///   - ingredients: Ingredients to match recipes against.
    ///   - sourceType: The specific backend to query.
    /// - Returns: Recipes matching the provided ingredients.
    /// - Throws: `RecipeSourceError` if the source is unavailable or the fetch fails.
    func getRecipes(for ingredients: [Ingredient], from sourceType: RecipeSourceType) async throws -> [Recipe]

    /// Returns whether a given source is currently usable.
    /// - Parameter sourceType: The source to check.
    /// - Returns: `true` if the source can be queried right now.
    func isSourceAvailable(_ sourceType: RecipeSourceType) async -> Bool

    /// Returns all source types that are currently available.
    /// - Returns: Array of available `RecipeSourceType` values in a deterministic order.
    func getAvailableSources() async -> [RecipeSourceType]

    /// Persists recipes directly into the local database cache.
    /// - Parameter recipes: Recipes to insert or replace.
    /// - Throws: `RecipeSourceError.databaseError` if the write fails.
    func storeRecipes(_ recipes: [Recipe]) throws

    /// Retrieves ingredient-matched recipes directly from the local database, bypassing any remote source.
    /// - Parameter ingredients: Ingredients to match against stored recipes.
    /// - Returns: Up to 20 recipes ordered by match quality.
    /// - Throws: `RecipeSourceError.databaseError` if the read fails.
    func getStoredRecipes(for ingredients: [Ingredient]) throws -> [Recipe]

    /// Fetches recipes from multiple sources concurrently, deduplicating by title.
    ///
    /// Sources are queried in a stable order. Partial failures (individual source errors)
    /// are tolerated and reflected in `hadSourceFailures` rather than throwing.
    /// - Parameters:
    ///   - ingredients: Ingredients to match recipes against.
    ///   - sourceTypes: The set of backends to query in this call.
    /// - Returns: A tuple of the merged, deduplicated recipe list and a flag indicating
    ///   whether at least one source encountered an error.
    /// - Throws: Only rethrows errors that prevent the entire call from completing.
    func getRecipes(for ingredients: [Ingredient], from sourceTypes: Set<RecipeSourceType>) async throws -> (recipes: [Recipe], hadSourceFailures: Bool)
}
