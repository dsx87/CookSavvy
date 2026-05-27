//
//  SupabaseLLMProvider.swift
//  CookSavvy
//

import Foundation
import Supabase

/// `LLMProviderProtocol` implementation that routes AI requests through Supabase Edge Functions,
/// keeping OpenAI/Gemini API keys entirely off the device.
///
/// Two edge functions are used:
/// - `detect-ingredients`: Accepts a base64-encoded image and returns detected ingredient names (vision request).
/// - `generate-recipes`: Accepts a chat message history and returns AI-generated recipe content (chat request).
///
/// Responses are decoded from a common `LLMFunctionResponse` envelope and mapped to `LLMResponse`.
/// Supabase SDK errors are translated to typed `LLMProviderError` values.
final class SupabaseLLMProvider: LLMProviderProtocol {
    /// Identifies this provider in logs and error messages.
    var name: String { "Supabase" }

    /// Edge function name constants used by this provider.
    private enum FunctionName {
        static let detectIngredients = "detect-ingredients"
        static let generateRecipes = "generate-recipes"
    }

    private let clientProvider: SupabaseClientProviderProtocol
    private let decoder: JSONDecoder

    /// - Parameters:
    ///   - clientProvider: Supabase client used to invoke edge functions.
    ///   - decoder: JSON decoder; configured with `.convertFromSnakeCase` to match edge function responses.
    init(
        clientProvider: SupabaseClientProviderProtocol,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.clientProvider = clientProvider
        self.decoder = decoder
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    /// Sends an image to the `detect-ingredients` edge function for AI-powered ingredient recognition.
    ///
    /// The image is base64-encoded and sent in the JSON body. The edge function constructs its own
    /// prompt server-side and returns `{ "ingredients": [{ "name": "...", "confidence": ... }] }`.
    /// The raw JSON is returned as `content` so `AIService.parseIngredientsResponse` can decode it
    /// (the `confidence` field is ignored by the decoder).
    /// - Parameters:
    ///   - imageData: Raw image bytes to be identified.
    ///   - mimeType: MIME type of the image (e.g. `"image/jpeg"`).
    ///   - prompt: Unused — the edge function builds its own prompt. Kept for protocol conformance.
    ///   - responseFormat: Unused — the edge function always returns JSON. Kept for protocol conformance.
    /// - Returns: An `LLMResponse` whose `content` is the raw JSON from the edge function.
    /// - Throws: `LLMProviderError` on network failure, HTTP error, or non-UTF-8 response.
    func sendVisionRequest(
        imageData: Data,
        mimeType: String,
        prompt: String,
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse {
        let request = VisionFunctionRequest(
            mimeType: mimeType,
            imageBase64: imageData.base64EncodedString()
        )

        let data: Data
        do {
            data = try await clientProvider.invokeFunction(FunctionName.detectIngredients, body: request)
        } catch {
            throw mapSupabaseError(error)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw LLMProviderError.decodingError(
                DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Response is not valid UTF-8")
                )
            )
        }

        return LLMResponse(content: content, tokensUsed: nil)
    }

    /// Sends a conversation history to the `generate-recipes` edge function.
    /// - Parameters:
    ///   - messages: Ordered list of chat messages (system + user turns).
    ///   - responseFormat: Expected output format (`json` or `text`).
    /// - Returns: An `LLMResponse` with the model's reply and optional token usage.
    /// - Throws: `LLMProviderError` on network failure, HTTP error, or decoding failure.
    func sendChatRequest(
        messages: [LLMMessage],
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse {
        let request = ChatFunctionRequest(
            messages: messages.map(ChatFunctionMessage.init),
            responseFormat: responseFormat.contractValue
        )

        return try await invokeLLMFunction(named: FunctionName.generateRecipes, body: request)
    }

    /// Shared invocation path for all LLM edge functions.
    ///
    /// Separates network errors (mapped via `mapSupabaseError`) from decoding errors
    /// so callers receive a precise `LLMProviderError` rather than a raw SDK or `DecodingError`.
    private func invokeLLMFunction<Request: Encodable>(named functionName: String, body: Request) async throws -> LLMResponse {
        let data: Data
        do {
            data = try await clientProvider.invokeFunction(functionName, body: body)
        } catch {
            throw mapSupabaseError(error)
        }

        do {
            let response = try decoder.decode(LLMFunctionResponse.self, from: data)
            return LLMResponse(
                content: response.content,
                tokensUsed: response.tokensUsed?.asTokenUsage
            )
        } catch {
            throw LLMProviderError.decodingError(error)
        }
    }

    /// Converts Supabase SDK errors (`AuthError`, `FunctionsError`) to `LLMProviderError`.
    /// HTTP errors are further refined by `mapHTTPError`.
    private func mapSupabaseError(_ error: Error) -> LLMProviderError {
        if error is AuthError {
            return .unknown(error)
        }

        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case .httpError(let code, let data):
                return mapHTTPError(statusCode: code, data: data)
            default:
                return .networkError(functionsError)
            }
        }

        return .networkError(error)
    }

    /// Maps HTTP status codes from edge function errors to semantic `LLMProviderError` cases.
    /// The response body is decoded as UTF-8 text and included in the error where available.
    private func mapHTTPError(statusCode: Int, data: Data?) -> LLMProviderError {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }

        switch statusCode {
        case 400:
            return .invalidRequest(message ?? "Bad request")
        case 401, 403:
            return .unknown(AuthError.notAuthenticated)
        case 404:
            return .modelUnavailable("Supabase edge function unavailable")
        case 429:
            return .rateLimitExceeded
        default:
            return .unknown(
                NSError(
                    domain: name,
                    code: statusCode,
                    userInfo: message.map { [NSLocalizedDescriptionKey: $0] }
                )
            )
        }
    }
}

/// Local wire-contract helpers for translating domain enums to edge-function payload strings.
private extension LLMResponseFormat {
    /// Converts the enum to the string value expected by the Supabase edge function contract.
    var contractValue: String {
        switch self {
        case .json:
            return "json"
        case .text:
            return "text"
        }
    }
}

/// Request body sent to the `detect-ingredients` edge function.
private struct VisionFunctionRequest: Encodable {
    let mimeType: String
    /// Base64-encoded image bytes.
    let imageBase64: String
}

/// Request body sent to the `generate-recipes` edge function.
private struct ChatFunctionRequest: Encodable {
    let messages: [ChatFunctionMessage]
    let responseFormat: String
}

/// Wire representation of a single chat message for the edge function API.
private struct ChatFunctionMessage: Encodable {
    let role: String
    let content: String

    /// Maps a domain `LLMMessage` to its wire representation.
    init(_ message: LLMMessage) {
        self.role = message.role.rawValue
        self.content = message.content
    }
}

/// Decoded response envelope returned by both LLM edge functions.
private struct LLMFunctionResponse: Decodable {
    let content: String
    let tokensUsed: LLMFunctionTokenUsage?
}

/// Token usage metadata included in an LLM edge function response.
private struct LLMFunctionTokenUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    /// Converts to the app's domain `TokenUsage` model.
    var asTokenUsage: TokenUsage {
        TokenUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens
        )
    }
}
