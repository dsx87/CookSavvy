//
//  OpenAIProvider.swift
//  CookSavvy
//

import Foundation
// TODO: review this
final class OpenAIProvider: LLMProviderProtocol {
    
    var name: String { "OpenAI" }
    
    private let apiKey: String
    private let model: String
    private let baseURL: URL
    private let networkService: NetworkServiceProtocol
    
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
    
    func sendVisionRequest(
        imageData: Data,
        mimeType: String,
        prompt: String,
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse {
        let base64Image = imageData.base64EncodedString()
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
    
    func sendChatRequest(
        messages: [LLMMessage],
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse {
        let openAIMessages = messages.map { message in
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

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let responseFormat: OpenAIResponseFormat?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
    }
}

private struct OpenAIMessage: Encodable {
    let role: String
    let content: OpenAIContent
}

private enum OpenAIContent: Encodable {
    case text(String)
    case vision([OpenAIVisionPart])
    
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

private enum OpenAIVisionPart: Encodable {
    case text(String)
    case imageURL(OpenAIImageURL)
    
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
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }
}

private struct OpenAIImageURL: Encodable {
    let url: String
    let detail: String
}

private struct OpenAIResponseFormat: Encodable {
    let type: String
}

private struct OpenAIResponse: Decodable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

private struct OpenAIChoice: Decodable {
    let message: OpenAIResponseMessage
}

private struct OpenAIResponseMessage: Decodable {
    let content: String
}

private struct OpenAIUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError
}

private struct OpenAIError: Decodable {
    let message: String
}
