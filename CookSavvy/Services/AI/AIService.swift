//
//  AIService.swift
//  CookSavvy
//

import Foundation
import os

final class AIService: AIServiceProtocol {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "AIService"
    )
    
    private let provider: LLMProviderProtocol
    
    init(provider: LLMProviderProtocol) {
        self.provider = provider
    }
    
    func detectIngredients(from imageData: Data) async throws -> [Ingredient] {
        guard !imageData.isEmpty else {
            throw AIServiceError.invalidImageData
        }
        
        let mimeType = detectMimeType(from: imageData)
        let prompt = Prompts.ingredientDetection
        
        Self.logger.debug("Sending vision request to \(self.provider.name)")
        
        do {
            let response = try await provider.sendVisionRequest(
                imageData: imageData,
                mimeType: mimeType,
                prompt: prompt,
                responseFormat: .json
            )
            
            if let usage = response.tokensUsed {
                Self.logger.debug("Tokens used: \(usage.totalTokens)")
            }
            
            let ingredients = try parseIngredientsResponse(response.content)
            
            guard !ingredients.isEmpty else {
                throw AIServiceError.noIngredientsDetected
            }
            
            Self.logger.info("Detected \(ingredients.count) ingredients")
            return ingredients
            
        } catch let error as LLMProviderError {
            throw AIServiceError.providerError(error)
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.unknown(error)
        }
    }
    
    func generateRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe] {
        guard !ingredients.isEmpty else {
            throw AIServiceError.noIngredientsDetected
        }
        
        let ingredientNames = ingredients.map { $0.name }.joined(separator: ", ")
        let prompt = Prompts.recipeGeneration(ingredients: ingredientNames, count: count)
        
        let messages: [LLMMessage] = [
            LLMMessage(role: .system, content: Prompts.recipeSystemPrompt),
            LLMMessage(role: .user, content: prompt)
        ]
        
        Self.logger.debug("Sending chat request to \(self.provider.name)")
        
        do {
            let response = try await provider.sendChatRequest(
                messages: messages,
                responseFormat: .json
            )
            
            if let usage = response.tokensUsed {
                Self.logger.debug("Tokens used: \(usage.totalTokens)")
            }
            
            let recipes = try parseRecipesResponse(response.content)
            
            guard !recipes.isEmpty else {
                throw AIServiceError.noRecipesGenerated
            }
            
            Self.logger.info("Generated \(recipes.count) recipes")
            return recipes
            
        } catch let error as LLMProviderError {
            throw AIServiceError.providerError(error)
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.unknown(error)
        }
    }
    
    private func detectMimeType(from data: Data) -> String {
        guard data.count >= 12 else { return "image/jpeg" }
        
        var bytes = [UInt8](repeating: 0, count: 12)
        data.copyBytes(to: &bytes, count: 12)
        
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "image/jpeg"
        } else if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        } else if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46,
                  bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50 {
            return "image/webp"
        } else if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return "image/gif"
        } else if bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 {
            return "image/heic"
        }
        
        Self.logger.warning("Unknown image format (magic: \(bytes[0...3].map { String(format: "%02X", $0) }.joined())), defaulting to JPEG")
        return "image/jpeg"
    }
    
    private func parseIngredientsResponse(_ content: String) throws -> [Ingredient] {
        guard let data = content.data(using: .utf8) else {
            throw AIServiceError.parsingFailed("Invalid UTF-8 content")
        }
        
        do {
            let response = try JSONDecoder().decode(IngredientsResponse.self, from: data)
            return response.ingredients.map { Ingredient(name: $0.name) }
        } catch {
            throw AIServiceError.parsingFailed(error.localizedDescription)
        }
    }
    
    private func parseRecipesResponse(_ content: String) throws -> [Recipe] {
        guard let data = content.data(using: .utf8) else {
            throw AIServiceError.parsingFailed("Invalid UTF-8 content")
        }
        
        do {
            let response = try JSONDecoder().decode(RecipesResponse.self, from: data)
            return response.recipes.map { recipeData in
                Recipe(
                    title: recipeData.title,
                    ingredients: recipeData.ingredients.map { Ingredient(name: $0) },
                    instructions: recipeData.instructions,
                    image: "",
                    cleanedIngredients: recipeData.ingredients.map { Ingredient(name: $0) },
                    additionalInfo: Recipe.AdditionalInfo(
                        time: recipeData.time,
                        servings: recipeData.servings,
                        complexity: recipeData.complexity,
                        calories: recipeData.calories
                    )
                )
            }
        } catch {
            throw AIServiceError.parsingFailed(error.localizedDescription)
        }
    }
}

private struct IngredientsResponse: Decodable {
    let ingredients: [IngredientData]
}

private struct IngredientData: Decodable {
    let name: String
}

private struct RecipesResponse: Decodable {
    let recipes: [RecipeData]
}

private struct RecipeData: Decodable {
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let time: String?
    let servings: Int?
    let complexity: String?
    let calories: Int?
}

private enum Prompts {
    static let ingredientDetection = """
        Analyze this image and identify all food ingredients visible.
        Return a JSON object with an "ingredients" array containing objects with "name" field.
        Only include actual food ingredients, not packaging or non-food items.
        Be specific (e.g., "Roma tomatoes" instead of just "tomatoes" if identifiable).
        
        Example response format:
        {"ingredients": [{"name": "Tomato"}, {"name": "Onion"}]}
        """
    
    static let recipeSystemPrompt = """
        You are a professional chef assistant. Generate recipes based on available ingredients.
        Always respond with valid JSON in the specified format.
        Create practical, delicious recipes that can be made with the given ingredients.
        Include realistic cooking times, serving sizes, and calorie estimates.
        """
    
    static func recipeGeneration(ingredients: String, count: Int) -> String {
        """
        Generate \(count) recipes using these ingredients: \(ingredients)
        
        You may suggest common pantry items (salt, pepper, oil, etc.) if needed.
        
        Return a JSON object with a "recipes" array. Each recipe should have:
        - "title": Recipe name
        - "ingredients": Array of ingredient strings with quantities
        - "instructions": Array of step-by-step instructions
        - "time": Cooking time (e.g., "30 min")
        - "servings": Number of servings (integer)
        - "complexity": "Easy", "Medium", or "Hard"
        - "calories": Estimated calories per serving (integer)
        
        Example format:
        {"recipes": [{"title": "Pasta", "ingredients": ["200g pasta"], "instructions": ["Boil water"], "time": "20 min", "servings": 2, "complexity": "Easy", "calories": 400}]}
        """
    }
}
