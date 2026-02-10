//
//  LLMProviderProtocol.swift
//  CookSavvy
//

import Foundation

protocol LLMProviderProtocol {
    var name: String { get }
    
    func sendVisionRequest(
        imageData: Data,
        mimeType: String,
        prompt: String,
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse
    
    func sendChatRequest(
        messages: [LLMMessage],
        responseFormat: LLMResponseFormat
    ) async throws -> LLMResponse
}

extension LLMProviderProtocol {
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
