//
//  MockShoppingListService.swift
//  CookSavvyTests
//

import Foundation
@testable import CookSavvy

final class MockShoppingListService: ShoppingListServiceProtocol {

    // MARK: - In-memory storage

    private var nextID = 1
    private(set) var items: [ShoppingItem] = []

    // MARK: - Configurable stubs

    var shouldThrow: Error?
    var stubbedToggleResult: Bool = false

    // MARK: - Call tracking

    var addItemsCalls: [(names: [String], recipeTitle: String?)] = []
    var toggleItemCalls: [ShoppingItem] = []
    var removeItemCalls: [ShoppingItem] = []
    var clearCompletedCallCount = 0

    // MARK: - Helpers

    func seed(names: [String], recipeTitle: String? = nil) {
        for name in names {
            let item = ShoppingItem(id: nextID, name: name, isChecked: false, addedAt: Date(), recipeTitle: recipeTitle)
            items.append(item)
            nextID += 1
        }
    }

    // MARK: - ShoppingListServiceProtocol

    func getItems() async throws -> [ShoppingItem] {
        if let error = shouldThrow { throw error }
        return items
    }

    func addItems(_ names: [String], recipeTitle: String?) async throws -> [ShoppingItem] {
        if let error = shouldThrow { throw error }
        addItemsCalls.append((names: names, recipeTitle: recipeTitle))
        var added: [ShoppingItem] = []
        for name in names {
            let item = ShoppingItem(id: nextID, name: name, isChecked: false, addedAt: Date(), recipeTitle: recipeTitle)
            items.append(item)
            added.append(item)
            nextID += 1
        }
        return added
    }

    func toggleItem(_ item: ShoppingItem) async throws -> Bool {
        if let error = shouldThrow { throw error }
        toggleItemCalls.append(item)
        if let index = items.firstIndex(of: item) {
            items[index].isChecked.toggle()
            return items[index].isChecked
        }
        return stubbedToggleResult
    }

    func removeItem(_ item: ShoppingItem) async throws {
        if let error = shouldThrow { throw error }
        removeItemCalls.append(item)
        items.removeAll { $0.id == item.id }
    }

    func clearCompleted() async throws {
        if let error = shouldThrow { throw error }
        clearCompletedCallCount += 1
        items.removeAll { $0.isChecked }
    }
}
