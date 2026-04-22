//
//  AIServiceError.swift
//  CookSavvy
//

import Foundation

/// High-level errors thrown by `AIServiceProtocol` methods.
///
/// These cases represent user-facing failure conditions at the AI feature layer.
/// Provider-specific failures are wrapped in `providerError` so callers can handle
/// them uniformly without knowing which `LLMProviderProtocol` implementation is active.
enum AIServiceError: Error, LocalizedError {
    /// No LLM provider was injected into `AIService`; AI operations are unavailable.
    case noProviderConfigured
    /// The model returned an empty ingredient list, or the supplied ingredient array was empty.
    case noIngredientsDetected
    /// The model returned no valid recipes.
    case noRecipesGenerated
    /// The image data passed to `detectIngredients` was empty.
    case invalidImageData
    /// The model's response could not be decoded into the expected JSON shape.
    case parsingFailed(String)
    /// A failure originating from the underlying `LLMProviderProtocol`.
    case providerError(LLMProviderError)
    /// An unexpected error that doesn't map to any known case.
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .noProviderConfigured:
            return "No AI provider configured"
        case .noIngredientsDetected:
            return "No ingredients detected in the image"
        case .noRecipesGenerated:
            return "Failed to generate recipes"
        case .invalidImageData:
            return "Invalid image data provided"
        case .parsingFailed(let details):
            return "Failed to parse AI response: \(details)"
        case .providerError(let error):
            return error.localizedDescription
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
