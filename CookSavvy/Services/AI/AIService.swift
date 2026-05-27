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
    
    private let visionProvider: LLMProviderProtocol?
    private let recipeGenerationProvider: RecipeAPIProviderProtocol?

    /// `true` when an AI recipe generation provider is configured; gates `AIRecipeSource` availability.
    var isAvailable: Bool { recipeGenerationProvider != nil }

    /// - Parameters:
    ///   - visionProvider: LLM backend used for vision-based ingredient detection. Pass `nil` to disable.
    ///   - recipeGenerationProvider: Backend used for AI recipe generation. Pass `nil` to disable.
    init(visionProvider: LLMProviderProtocol?, recipeGenerationProvider: RecipeAPIProviderProtocol? = nil) {
        self.visionProvider = visionProvider
        self.recipeGenerationProvider = recipeGenerationProvider
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
        guard let visionProvider else {
            throw AIServiceError.providerError(.invalidAPIKey)
        }

        let mimeType = detectMimeType(from: imageData)
        let prompt = Prompts.ingredientDetection

        Self.logger.debug("Sending vision request to \(visionProvider.name)")

        do {
            let response = try await visionProvider.sendVisionRequest(
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
    
    /// Generates AI-authored recipes for the given ingredients via the `generate-recipes` edge function.
    ///
    /// - Parameters:
    ///   - ingredients: The ingredients to cook with. Must be non-empty.
    ///   - count: How many recipe suggestions to request.
    /// - Returns: Generated `Recipe` values (may be fewer than `count`).
    /// - Throws: `AIServiceError.noIngredientsDetected` if ingredients is empty,
    ///   or `AIServiceError.providerError` / `AIServiceError.unknown` on network failures.
    func generateRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe] {
        guard !ingredients.isEmpty else {
            throw AIServiceError.noIngredientsDetected
        }
        guard let recipeGenerationProvider else {
            throw AIServiceError.providerError(.invalidAPIKey)
        }

        Self.logger.debug("Generating recipes via \(recipeGenerationProvider.name)")

        do {
            return try await recipeGenerationProvider.fetchRecipes(for: ingredients, count: count)
        } catch RecipeAPIProviderError.noResults {
            return []
        } catch let error as RecipeAPIProviderError {
            throw AIServiceError.providerError(.networkError(error))
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
    
}

/// Top-level JSON wrapper decoded from the ingredient-detection LLM response.
private struct IngredientsResponse: Decodable {
    let ingredients: [IngredientData]
}

/// Single ingredient entry inside an `IngredientsResponse`.
private struct IngredientData: Decodable {
    let name: String
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
}
