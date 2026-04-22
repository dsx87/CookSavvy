//
//  GeminiProvider.swift
//  CookSavvy
//

import Foundation
// TODO: review
/// Legacy direct-call `LLMProviderProtocol` implementation targeting the Google Gemini API
/// (`generateContent` endpoint).
///
/// Not wired in production — the active runtime routes through `SupabaseLLMProvider`. Retained
/// as a fallback and for potential future direct-API usage.
///
/// **Vision requests** attach the image as an `inlineData` part (base64 bytes + MIME type)
/// followed by the text prompt within a single content object.
///
/// **Chat requests** require special-casing for the `system` role: Gemini does not support
/// `system` as a regular `contents` turn; instead it is passed in the top-level
/// `system_instruction` field. `user` maps to `"user"` and `assistant` maps to `"model"`.
///
/// JSON mode is requested via `generationConfig.responseMimeType = "application/json"`.
/// The Gemini API may omit `totalTokenCount` in its usage metadata; the provider computes
/// a fallback by summing `promptTokenCount` and `candidatesTokenCount`.
final class GeminiProvider: LLMProviderProtocol {
    
    var name: String { "Gemini" }
    
    private let apiKey: String
    private let model: String
    private let baseURL: String
    private let networkService: NetworkServiceProtocol
    
    /// - Parameters:
    ///   - apiKey: Google AI Studio API key passed via the `x-goog-api-key` header.
    ///   - model: Gemini model identifier. Defaults to `gemini-2.0-flash`.
    ///   - baseURL: Base path for the Generative Language API. Overridable for testing.
    ///   - networkService: Network layer used to execute requests.
    init(
        apiKey: String,
        model: String = "gemini-2.0-flash",
        baseURL: String = "https://generativelanguage.googleapis.com/v1beta/models",
        networkService: NetworkServiceProtocol
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.networkService = networkService
    }
    
    /// Builds a Gemini `contents` array with an `inlineData` image part and a text part,
    /// then forwards to `sendRequest`.
    func sendVisionRequest(
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        .inlineData(GeminiInlineData(mimeType: mimeType, data: base64Image)),
                        .text(prompt)
                    ]
                )
            ],
            generationConfig: responseFormat == .json
                ? GeminiGenerationConfig(responseMimeType: "application/json")
                : nil
        )
        
        return try await sendRequest(body: requestBody)
    }
    
    /// Maps `LLMMessage` turns to Gemini's `contents` array, lifting any `system` role
    /// message into the dedicated `systemInstruction` field (the Gemini API does not accept
    /// `system` as a regular content role).
    func sendChatRequest(
        var systemInstruction: GeminiContent?
        
        for message in messages {
            switch message.role {
            case .system:
                systemInstruction = GeminiContent(parts: [.text(message.content)])
            case .user:
                contents.append(GeminiContent(role: "user", parts: [.text(message.content)]))
            case .assistant:
                contents.append(GeminiContent(role: "model", parts: [.text(message.content)]))
            }
        }
        
        let requestBody = GeminiRequest(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: responseFormat == .json
                ? GeminiGenerationConfig(responseMimeType: "application/json")
                : nil
        )
        
        return try await sendRequest(body: requestBody)
    }
    
    /// Constructs the endpoint URL from `baseURL/model:generateContent`, executes the POST,
    /// maps network errors, and decodes the Gemini response.
    ///
    /// Checks `promptFeedback.blockReason` before attempting to extract candidate text so that
    /// content-filtered responses map to `LLMProviderError.contentFiltered` rather than
    /// the more generic `invalidResponse`.
    private func sendRequest(body: GeminiRequest) async throws -> LLMResponse {
        guard let url = URL(string: "\(baseURL)/\(model):generateContent") else {
            throw LLMProviderError.invalidRequest("Invalid URL")
        }
        
        let request = NetworkRequest.post(
            url: url,
            body: body,
            headers: [
                "x-goog-api-key": apiKey
            ]
        )
        
        let networkResponse: NetworkResponse
        do {
            networkResponse = try await networkService.send(request)
        } catch let error as NetworkError {
            throw mapNetworkError(error) { data in
                (try? JSONDecoder().decode(GeminiErrorResponse.self, from: data))?.error.message
            }
        }
        
        let decoder = JSONDecoder()
        
        do {
            let geminiResponse = try decoder.decode(GeminiResponse.self, from: networkResponse.data)
            
            guard let candidate = geminiResponse.candidates?.first,
                  let part = candidate.content.parts.first else {
                if geminiResponse.promptFeedback?.blockReason != nil {
                    throw LLMProviderError.contentFiltered
                }
                throw LLMProviderError.invalidResponse
            }
            
            let tokenUsage: TokenUsage?
            if let usage = geminiResponse.usageMetadata {
                tokenUsage = TokenUsage(
                    promptTokens: usage.promptTokenCount,
                    completionTokens: usage.candidatesTokenCount ?? 0,
                    // Gemini API may omit totalTokenCount; compute fallback from available fields
                    totalTokens: usage.totalTokenCount ?? (usage.promptTokenCount + (usage.candidatesTokenCount ?? 0))
                )
            } else {
                tokenUsage = nil
            }
            
            return LLMResponse(content: part.text, tokensUsed: tokenUsage)
        } catch let error as LLMProviderError {
            throw error
        } catch {
            throw LLMProviderError.decodingError(error)
        }
    }
    
}

/// Top-level request body for the Gemini `generateContent` endpoint.
private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    var systemInstruction: GeminiContent?
    var generationConfig: GeminiGenerationConfig?
}

/// A single participant turn in the Gemini conversation. `role` is omitted for vision
/// requests and for `systemInstruction` (Gemini ignores the field in those positions).
private struct GeminiContent: Encodable {
    var role: String?
    let parts: [GeminiPart]
    
    /// Creates a Gemini message payload; omit `role` for system/vision-only payload contexts.
    init(role: String? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
}

/// A content part — either a text string or base64 inline image data.
/// Serialises to the Gemini-required shape: `{"text": "..."}` or `{"inline_data": {...}}`.
private enum GeminiPart: Encodable {
    case text(String)
    case inlineData(GeminiInlineData)
    
    /// Encodes to Gemini's polymorphic part object shape.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .inlineData(let data):
            try container.encode(data, forKey: .inlineData)
        }
    }
    
    /// Wire keys expected by the Gemini API for part payloads.
    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

/// Inline base64 image payload for a Gemini vision part.
/// Uses `mime_type` (snake_case) to satisfy the Gemini API field naming.
private struct GeminiInlineData: Encodable {
    let mimeType: String
    let data: String
    
    /// Maps Swift property names to Gemini's snake_case wire keys.
    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

/// Controls the MIME type of the generated output. Setting `responseMimeType` to
/// `"application/json"` enables Gemini's structured JSON output mode.
private struct GeminiGenerationConfig: Encodable {
    let responseMimeType: String
}

/// Top-level response from the Gemini `generateContent` endpoint.
private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
    let promptFeedback: GeminiPromptFeedback?
    let usageMetadata: GeminiUsageMetadata?
}

/// A single generation candidate from the Gemini response.
private struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent
}

/// The content object inside a Gemini candidate, containing one or more response parts.
private struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]
}

/// A text part within a Gemini response candidate.
private struct GeminiResponsePart: Decodable {
    let text: String
}

/// Safety-filter feedback for the original prompt. A non-nil `blockReason` means the request
/// was rejected before any candidates were generated.
private struct GeminiPromptFeedback: Decodable {
    let blockReason: String?
}

/// Token usage reported by Gemini. `candidatesTokenCount` and `totalTokenCount` are optional
/// because the API may omit them for certain model configurations.
private struct GeminiUsageMetadata: Decodable {
    let promptTokenCount: Int
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
}

/// Top-level error response body returned by the Gemini API on 4xx/5xx status codes.
private struct GeminiErrorResponse: Decodable {
    let error: GeminiError
}

/// The nested error object within `GeminiErrorResponse`.
private struct GeminiError: Decodable {
    let message: String
}
