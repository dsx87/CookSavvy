import Foundation

/// Interface for the premium shopping list CRUD operations.
///
/// Items are stored in the `shopping_items` SQLite table. Each item carries an id,
/// name, checked state, creation timestamp, and an optional recipe title.
protocol ShoppingListServiceProtocol: AnyObject {
    /// Fetches all shopping list items.
    /// - Returns: Every `ShoppingItem` currently in the list.
    /// - Throws: A database error if the fetch fails.
    func getItems() async throws -> [ShoppingItem]

    /// Bulk-inserts ingredient names as unchecked shopping items, optionally linked to a recipe.
    /// - Parameters:
    ///   - names: The names of ingredients to add.
    ///   - recipeTitle: The recipe the ingredients belong to, or `nil` if added manually.
    /// - Returns: The newly created `ShoppingItem` records.
    /// - Throws: A database error if the insert fails.
    func addItems(_ names: [String], recipeTitle: String?) async throws -> [ShoppingItem]

    /// Toggles the checked state of a shopping item.
    /// - Parameter item: The item to toggle.
    /// - Returns: The new checked state after toggling.
    /// - Throws: A database error if the update fails.
    func toggleItem(_ item: ShoppingItem) async throws -> Bool

    /// Permanently removes a single shopping item from the list.
    /// - Parameter item: The item to remove.
    /// - Throws: A database error if the deletion fails.
    func removeItem(_ item: ShoppingItem) async throws

    /// Deletes all shopping items that are currently marked as checked.
    /// - Throws: A database error if the deletion fails.
    func clearCompleted() async throws
}
