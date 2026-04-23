//
//  LLMProviderProtocol.swift
//  CookSavvy
//

import Foundation

/// Low-level abstraction over the app's backend LLM proxy or deterministic test mock.
///
/// Each conforming type is responsible for encoding requests into the format expected by its
/// API, executing the network call, and decoding the raw response into an `LLMResponse`.
/// Error normalisation (HTTP status → `LLMProviderError`) is provided by the default
/// `mapNetworkError` helper in the protocol extension.
///
/// `AIService` holds an optional reference to this protocol; all higher-level AI features
/// are built on top of these two primitive operations.
protocol LLMProviderProtocol {
    /// Human-readable identifier for logging and debugging (e.g. "Supabase", "Mock").
    var name: String { get }

    /// Returns `true` for mock implementations. Used by `AppContainer` to skip real network
    /// calls and by tests to verify the correct provider is injected.
    var isMock: Bool { get }

    /// Sends an image together with a text prompt to the LLM for visual understanding tasks
    /// such as ingredient detection.
    ///
    /// - Parameters:
    ///   - imageData: Raw image bytes to include in the request.
    ///   - mimeType: MIME type of the image (e.g. `"image/jpeg"`).
    ///   - prompt: Text instruction for the model.
    ///   - responseFormat: Whether the model should return plain text or a JSON object.
    /// - Returns: The model's response including content and optional token usage.
    /// - Throws: `LLMProviderError`
    func sendVisionRequest(
        imageData: Data,
        mimeType: String,
        prompt: String,
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse
    
    /// Sends a multi-turn chat conversation to the LLM for text generation tasks such as
    /// recipe creation.
    ///
    /// - Parameters:
    ///   - messages: Ordered conversation turns (system, user, assistant).
    ///   - responseFormat: Whether the model should return plain text or a JSON object.
    /// - Returns: The model's response including content and optional token usage.
    /// - Throws: `LLMProviderError`
    func sendChatRequest(
        messages: [LLMMessage],
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse
}

/// Shared default implementations for ``LLMProviderProtocol``.
extension LLMProviderProtocol {
    var isMock: Bool { false }

    /// Translates a `NetworkError` into a provider-specific `LLMProviderError`.
    ///
    /// HTTP 400 maps to `.invalidRequest`, 401/403 to `.invalidAPIKey`, 429 to
    /// `.rateLimitExceeded`, and all others to `.unknown`. The optional `extractMessage`
    /// closure allows providers to decode a human-readable message from the error body
    /// for inclusion in the returned error.
    ///
    /// - Parameters:
    ///   - error: The network-layer error to translate.
    ///   - extractMessage: Optional closure that decodes a message string from raw HTTP error body data.
    /// - Returns: The corresponding `LLMProviderError`.
    func mapNetworkError(
        _ error: NetworkError,
        extractMessage: ((Data) -> String?)? = nil
    ) -> LLMProviderError {
        switch error {
        case .httpError(let statusCode, let data):
            let message = data.flatMap { extractMessage?($0) }
            switch statusCode {
            case 400:
                return .invalidRequest(message ?? "Bad request")
            case 401, 403:
                return .invalidAPIKey
            case 429:
                return .rateLimitExceeded
            default:
                let userInfo: [String: Any]? = message.map {
                    [NSLocalizedDescriptionKey: $0]
                }
                return .unknown(NSError(domain: name, code: statusCode, userInfo: userInfo))
            }
        case .noConnection, .timeout:
            return .networkError(error)
        default:
            return .unknown(error)
        }
    }
}
