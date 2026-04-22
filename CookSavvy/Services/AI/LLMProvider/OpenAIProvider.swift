//
//  OpenAIProvider.swift
//  CookSavvy
//

import Foundation
// TODO: review this
/// Legacy direct-call `LLMProviderProtocol` implementation targeting the OpenAI Chat Completions API.
///
/// Not wired in production — the active runtime routes through `SupabaseLLMProvider`. Retained
/// in the codebase as a fallback and for potential future direct-API usage.
///
/// **Vision requests** encode the image as a base64 data URL and attach it as an `image_url`
/// content part alongside the text prompt within a single user message.
///
/// **Chat requests** map `LLMMessage` roles directly to OpenAI role strings and wrap them in
/// the standard `messages` array.
///
/// JSON mode is requested via `response_format: {"type": "json_object"}` when `responseFormat == .json`.
/// The response is decoded with `.convertFromSnakeCase` to handle OpenAI's snake_case field names.
final class OpenAIProvider: LLMProviderProtocol {
    
    var name: String { "OpenAI" }
    
    private let apiKey: String
    private let model: String
    private let baseURL: URL
    private let networkService: NetworkServiceProtocol
    
    /// - Parameters:
    ///   - apiKey: OpenAI secret key (`sk-…`).
    ///   - model: Model identifier. Defaults to `gpt-4o-mini` for cost-effective vision support.
    ///   - baseURL: Chat completions endpoint. Overridable for proxy/testing.
    ///   - networkService: Network layer used to execute requests.
    init(
        apiKey: String,
        model: String = "gpt-4o-mini",
        baseURL: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
        networkService: NetworkServiceProtocol
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.networkService = networkService
    }
    
    /// Encodes the image as a base64 data URL and sends it alongside the prompt in a single
    /// user message using OpenAI's multi-part vision content format.
    func sendVisionRequest(
        let dataURL = "data:\(mimeType);base64,\(base64Image)"
        
        let requestBody = OpenAIRequest(
            model: model,
            messages: [
                OpenAIMessage(
                    role: "user",
                    content: .vision([
                        .text(prompt),
                        .imageURL(OpenAIImageURL(url: dataURL, detail: "auto"))
                    ])
                )
            ],
            responseFormat: responseFormat == .json ? OpenAIResponseFormat(type: "json_object") : nil
        )
        
        return try await sendRequest(body: requestBody)
    }
    
    /// Maps `LLMMessage` roles to OpenAI role strings and builds a standard chat completions request.
    func sendChatRequest(
            OpenAIMessage(
                role: message.role.rawValue,
                content: .text(message.content)
            )
        }
        
        let requestBody = OpenAIRequest(
            model: model,
            messages: openAIMessages,
            responseFormat: responseFormat == .json ? OpenAIResponseFormat(type: "json_object") : nil
        )
        
        return try await sendRequest(body: requestBody)
    }
    
    /// Executes the HTTP POST, maps network errors, and decodes the Chat Completions response.
    /// Uses `.convertFromSnakeCase` decoding strategy to handle fields like `prompt_tokens`.
    private func sendRequest(body: OpenAIRequest) async throws -> LLMResponse {
        let request = NetworkRequest.post(
            url: baseURL,
            body: body,
            headers: [
                "Authorization": "Bearer \(apiKey)"
            ]
        )
        
        let networkResponse: NetworkResponse
        do {
            networkResponse = try await networkService.send(request)
        } catch let error as NetworkError {
            throw mapNetworkError(error) { data in
                (try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data))?.error.message
            }
        }
        
        let decoder = JSONDecoder()
        // OpenAI returns snake_case keys (e.g. prompt_tokens); Gemini uses camelCase natively
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let openAIResponse = try decoder.decode(OpenAIResponse.self, from: networkResponse.data)
            guard let choice = openAIResponse.choices.first else {
                throw LLMProviderError.invalidResponse
            }
            
            let tokenUsage: TokenUsage?
            if let usage = openAIResponse.usage {
                tokenUsage = TokenUsage(
                    promptTokens: usage.promptTokens,
                    completionTokens: usage.completionTokens,
                    totalTokens: usage.totalTokens
                )
            } else {
                tokenUsage = nil
            }
            
            return LLMResponse(content: choice.message.content, tokensUsed: tokenUsage)
        } catch let error as LLMProviderError {
            throw error
        } catch {
            throw LLMProviderError.decodingError(error)
        }
    }
    
}

/// Chat Completions request body.
private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let responseFormat: OpenAIResponseFormat?
    
    /// Wire key mapping for OpenAI Chat Completions request fields.
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
    }
}

/// A single message in the OpenAI messages array; content can be plain text or a vision part list.
private struct OpenAIMessage: Encodable {
    let role: String
    let content: OpenAIContent
}

/// Encodes message content as either a plain string (text) or an array of vision parts,
/// matching the polymorphic `content` field in the OpenAI Chat Completions API.
private enum OpenAIContent: Encodable {
    case text(String)
    case vision([OpenAIVisionPart])
    
    /// Encodes the polymorphic OpenAI `content` field as either string or part array.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .vision(let parts):
            try container.encode(parts)
        }
    }
}

/// An individual part within a vision content array — either a text string or an image URL object.
private enum OpenAIVisionPart: Encodable {
    case text(String)
    case imageURL(OpenAIImageURL)
    
    /// Encodes a vision part using OpenAI's required `{type,...}` object format.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let imageURL):
            try container.encode("image_url", forKey: .type)
            try container.encode(imageURL, forKey: .imageUrl)
        }
    }
    
    /// Wire keys for OpenAI vision parts.
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }
}

/// Image reference inside a vision part. `url` is a base64 data URL; `detail` controls
/// OpenAI's image processing resolution ("auto", "low", or "high").
private struct OpenAIImageURL: Encodable {
    let url: String
    let detail: String
}

/// Requests a structured output type from the model (e.g. `{"type": "json_object"}`).
private struct OpenAIResponseFormat: Encodable {
    let type: String
}

/// Top-level Chat Completions response from the OpenAI API.
private struct OpenAIResponse: Decodable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

/// A single completion candidate returned by the API.
private struct OpenAIChoice: Decodable {
    let message: OpenAIResponseMessage
}

/// The assistant message contained within a completion choice.
private struct OpenAIResponseMessage: Decodable {
    let content: String
}

/// Token usage fields from the OpenAI response (snake_case decoded via `.convertFromSnakeCase`).
private struct OpenAIUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

/// Top-level error response body returned by the OpenAI API on 4xx/5xx status codes.
private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError
}

/// The nested error object within `OpenAIErrorResponse`.
private struct OpenAIError: Decodable {
    let message: String
}
