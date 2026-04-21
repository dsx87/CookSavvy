import Foundation

final class SpoonacularProvider: RecipeAPIProviderProtocol, @unchecked Sendable {

    var name: String { "Spoonacular" }

    private let apiKey: String
    private let networkService: NetworkServiceProtocol
    private let baseURL = "https://api.spoonacular.com"

    init(apiKey: String, networkService: NetworkServiceProtocol) {
        self.apiKey = apiKey
        self.networkService = networkService
    }

    func fetchRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe] {
        guard !ingredients.isEmpty else { throw RecipeAPIProviderError.noResults }

        let ingredientString = ingredients.map { $0.name }.joined(separator: ",")

        let url = try URLBuilder(baseURL: baseURL)
            .withPath("recipes/complexSearch")
            .build()

        let request = NetworkRequest.get(
            url: url,
            queryParameters: [
                "apiKey": apiKey,
                "includeIngredients": ingredientString,
                "addRecipeInformation": "true",
                "addRecipeInstructions": "true",
                "sort": "max-used-ingredients",
                "instructionsRequired": "true",
                "fillIngredients": "true",
                "number": String(count)
            ]
        )

        let response: NetworkResponse
        do {
            response = try await networkService.send(request)
        } catch let error as NetworkError {
            throw mapNetworkError(error)
        }

        let searchResponse: SpoonacularSearchResponse
        do {
            searchResponse = try response.decode(SpoonacularSearchResponse.self)
        } catch {
            throw RecipeAPIProviderError.invalidResponse
        }
        let recipes = SpoonacularMapper.mapRecipes(searchResponse.results)

        if recipes.isEmpty { throw RecipeAPIProviderError.noResults }
        return recipes
    }

    func isAvailable() async -> Bool {
        return true
    }

    private func mapNetworkError(_ error: NetworkError) -> RecipeAPIProviderError {
        switch error {
        case .httpError(let statusCode, _):
            switch statusCode {
            case 401, 403:
                return .invalidAPIKey
            case 402, 429:
                return .rateLimitExceeded
            default:
                return .networkError(error)
            }
        case .noConnection, .timeout:
            return .networkError(error)
        default:
            return .networkError(error)
        }
    }
}
