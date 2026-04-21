//
//  SupabaseLLMProvider.swift
//  CookSavvy
//

import Foundation
import Supabase

final class SupabaseLLMProvider: LLMProviderProtocol {
    var name: String { "Supabase" }

    private enum FunctionName {
        static let detectIngredients = "detect-ingredients"
        static let generateRecipes = "generate-recipes"
    }

    private let clientProvider: SupabaseClientProviderProtocol
    private let decoder: JSONDecoder

    init(
        clientProvider: SupabaseClientProviderProtocol,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.clientProvider = clientProvider
        self.decoder = decoder
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func sendVisionRequest(
        imageData: Data,
        mimeType: String,
        prompt: String,
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse {
        let request = VisionFunctionRequest(
            prompt: prompt,
            mimeType: mimeType,
            imageBase64: imageData.base64EncodedString(),
            responseFormat: responseFormat.contractValue
        )

        return try await invokeLLMFunction(named: FunctionName.detectIngredients, body: request)
    }

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

private extension LLMResponseFormat {
    var contractValue: String {
        switch self {
        case .json:
            return "json"
        case .text:
            return "text"
        }
    }
}

private struct VisionFunctionRequest: Encodable {
    let prompt: String
    let mimeType: String
    let imageBase64: String
    let responseFormat: String
}

private struct ChatFunctionRequest: Encodable {
    let messages: [ChatFunctionMessage]
    let responseFormat: String
}

private struct ChatFunctionMessage: Encodable {
    let role: String
    let content: String

    init(_ message: LLMMessage) {
        self.role = message.role.rawValue
        self.content = message.content
    }
}

private struct LLMFunctionResponse: Decodable {
    let content: String
    let tokensUsed: LLMFunctionTokenUsage?
}

private struct LLMFunctionTokenUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    var asTokenUsage: TokenUsage {
        TokenUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens
        )
    }
}
