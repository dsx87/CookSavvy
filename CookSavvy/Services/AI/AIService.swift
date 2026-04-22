//
//  AIService.swift
//  CookSavvy
//

import Foundation
import os

/// Concrete implementation of `AIServiceProtocol` that delegates all LLM work to an injected
/// `LLMProviderProtocol`. `AIService` owns prompt construction, image MIME-type detection,
/// input sanitization, and JSON response parsing — the provider only needs to send bytes and
/// return raw text.
///
/// The provider is optional; when `nil` the service reports itself as unavailable, allowing
/// the app to gracefully hide AI features rather than surfacing errors.
final class AIService: AIServiceProtocol {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "AIService"
    )
    
    private let provider: LLMProviderProtocol?

    /// Whether an LLM provider was injected and is ready to receive requests.
    var isAvailable: Bool { provider != nil }

    /// - Parameter provider: The LLM backend to use. Pass `nil` to disable AI features
    ///   without causing runtime errors (e.g., when API keys are absent).
    init(provider: LLMProviderProtocol?) {
        self.provider = provider
    }

    /// Detects food ingredients from raw image bytes by sending a vision request to the LLM.
    ///
    /// The MIME type is sniffed from the image magic bytes so callers don't need to track the
    /// format. `LLMProviderError`s are re-wrapped into `AIServiceError.providerError` to keep
    /// the higher-level error contract stable across provider changes.
    ///
    /// - Parameter imageData: Raw image bytes. Must be non-empty.
    /// - Returns: Detected `Ingredient` values parsed from the model's JSON response.
    /// - Throws: `AIServiceError.invalidImageData`, `AIServiceError.noIngredientsDetected`,
    ///   `AIServiceError.parsingFailed`, or `AIServiceError.providerError`.
    func detectIngredients(from imageData: Data) async throws -> [Ingredient] {
        guard !imageData.isEmpty else {
            throw AIServiceError.invalidImageData
        }
        guard let provider else {
            throw AIServiceError.providerError(.invalidAPIKey)
        }

        let mimeType = detectMimeType(from: imageData)
        let prompt = Prompts.ingredientDetection

        Self.logger.debug("Sending vision request to \(provider.name)")
        
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
    
    /// Generates AI-authored recipes for the given ingredients via a chat request to the LLM.
    ///
    /// Ingredient names are sanitized before being embedded in the prompt (newlines stripped,
    /// length capped at 100 chars each) to prevent prompt injection and oversized payloads.
    /// A system message establishes the chef persona so the model outputs structured JSON.
    ///
    /// - Parameters:
    ///   - ingredients: The ingredients to cook with. Must be non-empty.
    ///   - count: How many recipe suggestions to request.
    /// - Returns: Parsed `Recipe` values from the model's JSON response.
    /// - Throws: `AIServiceError.noIngredientsDetected`, `AIServiceError.noRecipesGenerated`,
    ///   `AIServiceError.parsingFailed`, or `AIServiceError.providerError`.
    func generateRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe] {
        guard !ingredients.isEmpty else {
            throw AIServiceError.noIngredientsDetected
        }
        guard let provider else {
            throw AIServiceError.providerError(.invalidAPIKey)
        }

        let ingredientNames = ingredients
            .map { Self.sanitizedIngredientName($0.name) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !ingredientNames.isEmpty else {
            throw AIServiceError.noIngredientsDetected
        }
        let prompt = Prompts.recipeGeneration(ingredients: ingredientNames, count: count)

        let messages: [LLMMessage] = [
            LLMMessage(role: .system, content: Prompts.recipeSystemPrompt),
            LLMMessage(role: .user, content: prompt)
        ]

        Self.logger.debug("Sending chat request to \(provider.name)")

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
    
    /// Sniffs the MIME type from the first 12 magic bytes of image data.
    ///
    /// Inspects well-known byte signatures for JPEG (FF D8 FF), PNG (89 50 4E 47),
    /// WebP (RIFF…WEBP), GIF (47 49 46), and HEIC (ftyp box at offset 4).
    /// Defaults to `image/jpeg` for any unrecognised format.
    ///
    /// - Parameter data: Raw image bytes.
    /// - Returns: A MIME type string suitable for multipart or base64 data-URL payloads.
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

    /// Strips control characters and newlines from an ingredient name, then caps it at 100 characters.
    /// Prevents prompt injection and avoids oversized tokens when ingredient names are user-supplied.
    private static func sanitizedIngredientName(_ name: String) -> String {
        let stripped = name
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.count > 100 else { return stripped }
        return String(stripped.prefix(100))
    }
    
    /// Decodes the LLM's JSON text into an array of `Ingredient` values.
    /// - Throws: `AIServiceError.parsingFailed` if the content is not valid UTF-8 or does not
    ///   conform to the expected `{"ingredients": [{"name": "..."}]}` shape.
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
    
    /// Decodes the LLM's JSON text into an array of `Recipe` values.
    /// - Throws: `AIServiceError.parsingFailed` if the content is not valid UTF-8 or does not
    ///   conform to the expected `{"recipes": [...]}` shape.
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
                    instructions: recipeData.instructions.map(Recipe.Step.init(plainText:)),
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

/// Top-level JSON wrapper decoded from the ingredient-detection LLM response.
private struct IngredientsResponse: Decodable {
    let ingredients: [IngredientData]
}

/// Single ingredient entry inside an `IngredientsResponse`.
private struct IngredientData: Decodable {
    let name: String
}

/// Top-level JSON wrapper decoded from the recipe-generation LLM response.
private struct RecipesResponse: Decodable {
    let recipes: [RecipeData]
}

/// Single recipe entry inside a `RecipesResponse`.
private struct RecipeData: Decodable {
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let time: String?
    let servings: Int?
    let complexity: String?
    let calories: Int?
}

/// Prompt templates used by `AIService` when constructing LLM requests.
/// Centralising prompts here makes them easy to iterate without touching request logic.
private enum Prompts {
    /// Prompt instructing the model to return detected ingredients as a JSON object.
    static let ingredientDetection = """
        Analyze this image and identify all food ingredients visible.
        Return a JSON object with an "ingredients" array containing objects with "name" field.
        Only include actual food ingredients, not packaging or non-food items.
        Be specific (e.g., "Roma tomatoes" instead of just "tomatoes" if identifiable).
        
        Example response format:
        {"ingredients": [{"name": "Tomato"}, {"name": "Onion"}]}
        """
    
    /// System message establishing the chef persona for the recipe-generation conversation.
    static let recipeSystemPrompt = """
        You are a professional chef assistant. Generate recipes based on available ingredients.
        Always respond with valid JSON in the specified format.
        Create practical, delicious recipes that can be made with the given ingredients.
        Include realistic cooking times, serving sizes, and calorie estimates.
        """
    
    /// Builds the user turn for a recipe-generation chat, embedding the ingredient list and count.
    /// - Parameters:
    ///   - ingredients: Comma-separated, sanitized ingredient names.
    ///   - count: Number of recipes to generate.
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
