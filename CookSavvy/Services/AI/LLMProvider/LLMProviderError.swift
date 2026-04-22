//
//  LLMProviderError.swift
//  CookSavvy
//

import Foundation

/// Provider-level errors thrown by `LLMProviderProtocol` implementations.
///
/// These are low-level cases that reflect API-specific failure modes. `AIService` catches them
/// and re-wraps them into `AIServiceError.providerError` so the rest of the app never
/// depends on this enum directly.
enum LLMProviderError: Error, LocalizedError {
    /// The API key is missing, invalid, or not authorised for the requested model.
    case invalidAPIKey
    /// The provider is temporarily throttling requests; the caller should retry later.
    case rateLimitExceeded
    /// The account's monthly or daily token quota has been exhausted.
    case quotaExceeded
    /// The request payload was malformed or contained unsupported parameters.
    case invalidRequest(String)
    /// The requested model identifier is not currently available on the provider.
    case modelUnavailable(String)
    /// The prompt or response was blocked by the provider's content safety filters.
    case contentFiltered
    /// The API returned a response that could not be interpreted (e.g., missing required fields).
    case invalidResponse
    /// A network-layer error such as no connectivity or a timeout.
    case networkError(Error)
    /// The API response body could not be decoded into the expected types.
    case decodingError(Error)
    /// An unexpected error that doesn't map to any known provider failure mode.
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .quotaExceeded:
            return "API quota exceeded"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .modelUnavailable(let model):
            return "Model '\(model)' is unavailable"
        case .contentFiltered:
            return "Content was filtered by safety settings"
        case .invalidResponse:
            return "Invalid response from API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
