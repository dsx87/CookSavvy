//
//  MockLLMProvider.swift
//  CookSavvy
//

import Foundation

#if DEBUG
final class MockLLMProvider: LLMProviderProtocol {
    
    var name: String { "Mock" }
    var isMock: Bool { true }
    
    private let simulatedDelay: TimeInterval
    private let shouldSucceed: Bool
    private let mockIngredientsResponse: String
    private let mockRecipesResponse: String
    
    init(
        simulatedDelay: TimeInterval = 1.0,
        shouldSucceed: Bool = true,
        mockIngredients: [String]? = nil,
        mockRecipes: [MockRecipeData]? = nil
    ) {
        self.simulatedDelay = simulatedDelay
        self.shouldSucceed = shouldSucceed
        
        let ingredients = mockIngredients ?? ["Tomato", "Onion", "Garlic", "Olive Oil", "Basil"]
        self.mockIngredientsResponse = Self.buildIngredientsJSON(ingredients)
        
        let recipes = mockRecipes ?? [
            MockRecipeData(
                title: "Classic Tomato Pasta",
                ingredients: ["Pasta", "Tomato", "Garlic", "Olive Oil", "Basil"],
                instructions: ["Boil pasta", "Sauté garlic in olive oil", "Add tomatoes", "Combine and serve with basil"],
                time: "25 min",
                servings: 4,
                complexity: "Easy",
                calories: 450
            ),
            MockRecipeData(
                title: "Garden Salad",
                ingredients: ["Lettuce", "Tomato", "Onion", "Olive Oil", "Lemon"],
                instructions: ["Wash vegetables", "Chop into pieces", "Mix in bowl", "Dress with oil and lemon"],
                time: "10 min",
                servings: 2,
                complexity: "Easy",
                calories: 150
            )
        ]
        self.mockRecipesResponse = Self.buildRecipesJSON(recipes)
    }
    
    func sendVisionRequest(
        imageData: Data,
        mimeType: String,
        prompt: String,
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse {
        try await simulateDelay()
        try checkSuccess()
        
        return LLMResponse(
            content: mockIngredientsResponse,
            tokensUsed: TokenUsage(promptTokens: 100, completionTokens: 50, totalTokens: 150)
        )
    }
    
    func sendChatRequest(
        messages: [LLMMessage],
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse {
        try await simulateDelay()
        try checkSuccess()
        
        return LLMResponse(
            content: mockRecipesResponse,
            tokensUsed: TokenUsage(promptTokens: 200, completionTokens: 300, totalTokens: 500)
        )
    }
    
    private func simulateDelay() async throws {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
    }
    
    private func checkSuccess() throws {
        guard shouldSucceed else {
            throw LLMProviderError.unknown(NSError(
                domain: "MockLLMProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Simulated failure"]
            ))
        }
    }
    
    private static func buildIngredientsJSON(_ ingredients: [String]) -> String {
        let ingredientObjects = ingredients.map { "{ \"name\": \"\($0)\" }" }
        return "{ \"ingredients\": [\(ingredientObjects.joined(separator: ", "))] }"
    }
    
    private static func buildRecipesJSON(_ recipes: [MockRecipeData]) -> String {
        let recipeObjects = recipes.map { recipe -> String in
            let ingredientsArray = recipe.ingredients.map { "\"\($0)\"" }.joined(separator: ", ")
            let instructionsArray = recipe.instructions.map { "\"\($0)\"" }.joined(separator: ", ")
            return """
            {
                "title": "\(recipe.title)",
                "ingredients": [\(ingredientsArray)],
                "instructions": [\(instructionsArray)],
                "time": "\(recipe.time)",
                "servings": \(recipe.servings),
                "complexity": "\(recipe.complexity)",
                "calories": \(recipe.calories)
            }
            """
        }
        return "{ \"recipes\": [\(recipeObjects.joined(separator: ", "))] }"
    }
}

struct MockRecipeData {
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let time: String
    let servings: Int
    let complexity: String
    let calories: Int
}
#endif
