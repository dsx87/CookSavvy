import Foundation

protocol ShoppingListServiceProtocol: AnyObject {
    func getItems() async throws -> [ShoppingItem]
    func addItems(_ names: [String], recipeTitle: String?) async throws -> [ShoppingItem]
    func toggleItem(_ item: ShoppingItem) async throws -> Bool
    func removeItem(_ item: ShoppingItem) async throws
    func clearCompleted() async throws
}
