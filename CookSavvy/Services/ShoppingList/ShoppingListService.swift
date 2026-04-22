//
//  ShoppingListService.swift
//  CookSavvy
//

import Foundation

/// CRUD service for the premium shopping list feature.
///
/// Delegates all persistence to `DBInterfaceProtocol`, which maps to the
/// `shopping_items` SQLite table. Operations include bulk-adding ingredients
/// from a recipe's missing-items list, toggling the checked state of individual
/// items, and removing or clearing completed items.
final class ShoppingListService: ShoppingListServiceProtocol {
    private let dbInterface: DBInterfaceProtocol

    /// Creates a shopping list service backed by the given database interface.
    /// - Parameter dbInterface: The database interface used for all persistence operations.
    init(dbInterface: DBInterfaceProtocol) {
        self.dbInterface = dbInterface
    }

    /// Fetches all shopping items, ordered as stored in the database.
    /// - Returns: An array of all current `ShoppingItem` records.
    /// - Throws: A database error if the query fails.
    func getItems() async throws -> [ShoppingItem] {
        try dbInterface.getShoppingItems()
    }

    /// Bulk-inserts ingredient names as new unchecked shopping items, optionally tagged with a recipe title.
    ///
    /// Intended for the "Add Missing to List" action on the Recipe Details screen,
    /// which may add multiple ingredients in a single operation.
    /// - Parameters:
    ///   - names: The ingredient names to add.
    ///   - recipeTitle: The recipe the ingredients belong to, or `nil` if added manually.
    /// - Returns: The newly created `ShoppingItem` records.
    /// - Throws: A database error if the insert fails.
    func addItems(_ names: [String], recipeTitle: String?) async throws -> [ShoppingItem] {
        try dbInterface.addShoppingItems(names, recipeTitle: recipeTitle)
    }

    /// Toggles the `isChecked` state of the given item.
    /// - Parameter item: The item to toggle.
    /// - Returns: The new checked state of the item.
    /// - Throws: A database error if the update fails.
    func toggleItem(_ item: ShoppingItem) async throws -> Bool {
        try dbInterface.toggleShoppingItem(id: item.id)
    }

    /// Permanently removes a single shopping item.
    /// - Parameter item: The item to remove.
    /// - Throws: A database error if the deletion fails.
    func removeItem(_ item: ShoppingItem) async throws {
        try dbInterface.removeShoppingItem(id: item.id)
    }

    /// Deletes all items that are currently marked as checked.
    /// - Throws: A database error if the deletion fails.
    func clearCompleted() async throws {
        try dbInterface.clearCheckedShoppingItems()
    }
}
