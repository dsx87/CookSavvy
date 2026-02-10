//
//  GeminiProvider.swift
//  CookSavvy
//

import Foundation
// TODO: review
final class GeminiProvider: LLMProviderProtocol {
    
    var name: String { "Gemini" }
    
    private let apiKey: String
    private let model: String
    private let baseURL: String
    private let networkService: NetworkServiceProtocol
    
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
    
    func sendVisionRequest(
        imageData: Data,
        mimeType: String,
        prompt: String,
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse {
        let base64Image = imageData.base64EncodedString()
        
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
    
    func sendChatRequest(
        messages: [LLMMessage],
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse {
        var contents: [GeminiContent] = []
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

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    var systemInstruction: GeminiContent?
    var generationConfig: GeminiGenerationConfig?
}

private struct GeminiContent: Encodable {
    var role: String?
    let parts: [GeminiPart]
    
    init(role: String? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
}

private enum GeminiPart: Encodable {
    case text(String)
    case inlineData(GeminiInlineData)
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .inlineData(let data):
            try container.encode(data, forKey: .inlineData)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

private struct GeminiInlineData: Encodable {
    let mimeType: String
    let data: String
    
    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GeminiGenerationConfig: Encodable {
    let responseMimeType: String
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
    let promptFeedback: GeminiPromptFeedback?
    let usageMetadata: GeminiUsageMetadata?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent
}

private struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]
}

private struct GeminiResponsePart: Decodable {
    let text: String
}

private struct GeminiPromptFeedback: Decodable {
    let blockReason: String?
}

private struct GeminiUsageMetadata: Decodable {
    let promptTokenCount: Int
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
}

private struct GeminiErrorResponse: Decodable {
    let error: GeminiError
}

private struct GeminiError: Decodable {
    let message: String
}
