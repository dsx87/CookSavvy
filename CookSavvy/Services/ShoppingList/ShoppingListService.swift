//
//  ShoppingListService.swift
//  CookSavvy
//

import Foundation

final class ShoppingListService: ShoppingListServiceProtocol {
    private let dbInterface: DBInterfaceProtocol

    init(dbInterface: DBInterfaceProtocol) {
        self.dbInterface = dbInterface
    }

    func getItems() async throws -> [ShoppingItem] {
        try dbInterface.getShoppingItems()
    }

    func addItems(_ names: [String], recipeTitle: String?) async throws -> [ShoppingItem] {
        try dbInterface.addShoppingItems(names, recipeTitle: recipeTitle)
    }

    func toggleItem(_ item: ShoppingItem) async throws -> Bool {
        try dbInterface.toggleShoppingItem(id: item.id)
    }

    func removeItem(_ item: ShoppingItem) async throws {
        try dbInterface.removeShoppingItem(id: item.id)
    }

    func clearCompleted() async throws {
        try dbInterface.clearCheckedShoppingItems()
    }
}
