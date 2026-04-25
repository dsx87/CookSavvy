import Foundation

/// Interface for the free pantry-staples feature.
///
/// Pantry ingredients are persisted separately from the current Discover selection and
/// are treated as always available when searching and calculating recipe matches.
protocol PantryServiceProtocol: AnyObject {
    /// Fetches all ingredients the user has marked as always available.
    func getItems() async throws -> [Ingredient]

    /// Adds an ingredient to the user's always-available pantry staples.
    func addItem(_ ingredient: Ingredient) async throws

    /// Removes an ingredient from the user's pantry staples.
    func removeItem(_ ingredient: Ingredient) async throws

    /// Returns whether an ingredient is currently in the pantry.
    func contains(_ ingredient: Ingredient) async throws -> Bool
}
