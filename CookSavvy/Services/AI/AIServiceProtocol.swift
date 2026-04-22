//
//  AIServiceProtocol.swift
//  CookSavvy
//

import Foundation

/// High-level AI interface for ingredient detection and recipe generation.
///
/// This is the app-facing abstraction over the LLM provider layer. Features that need AI
/// (camera ingredient detection, AI recipe source) depend on this protocol rather than
/// a concrete provider, enabling easy swapping of the underlying LLM backend.
protocol AIServiceProtocol {
    /// Whether an LLM provider is configured. Returns `false` when no provider was injected,
    /// preventing AI-related UI from attempting requests that would immediately fail.
    var isAvailable: Bool { get }

    /// Detects food ingredients visible in the supplied image data.
    ///
    /// - Parameter imageData: Raw image bytes (JPEG, PNG, WebP, GIF, or HEIC).
    /// - Returns: A list of detected `Ingredient` values.
    /// - Throws: `AIServiceError.invalidImageData` if the data is empty,
    ///   `AIServiceError.noIngredientsDetected` if the model returns an empty list,
    ///   or an `AIServiceError` wrapping any provider-level failure.
    func detectIngredients(from imageData: Data) async throws -> [Ingredient]

    /// Generates AI-authored recipes based on the supplied ingredients.
    ///
    /// - Parameters:
    ///   - ingredients: Ingredients to base the recipes on.
    ///   - count: Number of recipes to request from the model.
    /// - Returns: An array of generated `Recipe` values (may be fewer than `count` if the model returns less).
    /// - Throws: `AIServiceError.noIngredientsDetected` if `ingredients` is empty,
    ///   `AIServiceError.noRecipesGenerated` if the model returns no valid recipes,
    ///   or an `AIServiceError` wrapping any provider-level failure.
    func generateRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe]
}
