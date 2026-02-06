//
//  LLMProviderError.swift
//  CookSavvy
//

import Foundation

enum LLMProviderError: Error, LocalizedError {
    case invalidAPIKey
    case rateLimitExceeded
    case quotaExceeded
    case invalidRequest(String)
    case modelUnavailable(String)
    case contentFiltered
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
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
