import Foundation

protocol RecipeServiceProtocol: AnyObject {
    func getRecipes(for ingredients: [Ingredient], from sourceType: RecipeSourceType) async throws -> [Recipe]
    func isSourceAvailable(_ sourceType: RecipeSourceType) async -> Bool
    func getAvailableSources() async -> [RecipeSourceType]
    func storeRecipes(_ recipes: [Recipe]) throws
    func getStoredRecipes(for ingredients: [Ingredient]) throws -> [Recipe]
    func getRecipes(for ingredients: [Ingredient], from sourceTypes: Set<RecipeSourceType>) async throws -> [Recipe]
}
