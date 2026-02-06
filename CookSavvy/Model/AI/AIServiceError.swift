//
//  AIServiceError.swift
//  CookSavvy
//

import Foundation

enum AIServiceError: Error, LocalizedError {
    case noProviderConfigured
    case noIngredientsDetected
    case noRecipesGenerated
    case invalidImageData
    case parsingFailed(String)
    case providerError(LLMProviderError)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .noProviderConfigured:
            return "No AI provider configured"
        case .noIngredientsDetected:
            return "No ingredients detected in the image"
        case .noRecipesGenerated:
            return "Failed to generate recipes"
        case .invalidImageData:
            return "Invalid image data provided"
        case .parsingFailed(let details):
            return "Failed to parse AI response: \(details)"
        case .providerError(let error):
            return error.localizedDescription
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
