import Foundation

protocol IngredientsServiceProtocol: AnyObject {
    func ensureIngredientsLoaded() async throws
    func searchIngredients(matching query: String, limit: Int) async throws -> [String]
    func searchFullIngredients(matching query: String, limit: Int) async throws -> [Ingredient]
    func getIngredient(byName name: String) async throws -> Ingredient?
    func getAllIngredients(category: IngredientCategory?, limit: Int) async throws -> [Ingredient]
    func getCategories() async throws -> [IngredientCategory]
    func forceReimport() async throws
}

extension IngredientsServiceProtocol {
    // Defaults must stay in sync with IngredientsService.Constants
    func searchIngredients(matching query: String) async throws -> [String] {
        try await searchIngredients(matching: query, limit: 50)
    }

    func searchFullIngredients(matching query: String) async throws -> [Ingredient] {
        try await searchFullIngredients(matching: query, limit: 50)
    }

    func getAllIngredients(category: IngredientCategory? = nil) async throws -> [Ingredient] {
        try await getAllIngredients(category: category, limit: 100)
    }
}
