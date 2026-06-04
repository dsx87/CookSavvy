import Foundation

/// Persistence-backed service for free pantry staples.
///
/// The service is intentionally thin: `PantryStoreProtocol` owns canonical-name
/// resolution and SQLite persistence, while callers use this protocol boundary for
/// testable Discover behavior.
final class PantryService: PantryServiceProtocol {
    private let dbInterface: PantryStoreProtocol

    /// Creates a pantry service backed by the given database interface.
    /// - Parameter dbInterface: The database interface used for pantry persistence.
    init(dbInterface: PantryStoreProtocol) {
        self.dbInterface = dbInterface
    }

    /// Fetches all pantry staples.
    func getItems() async throws -> [Ingredient] {
        try dbInterface.getPantryItems()
    }

    /// Adds an ingredient to pantry staples.
    func addItem(_ ingredient: Ingredient) async throws {
        try dbInterface.addPantryItem(ingredient)
    }

    /// Removes an ingredient from pantry staples.
    func removeItem(_ ingredient: Ingredient) async throws {
        try dbInterface.removePantryItem(ingredient)
    }

    /// Checks pantry membership.
    func contains(_ ingredient: Ingredient) async throws -> Bool {
        try dbInterface.isPantryItem(ingredient)
    }
}
