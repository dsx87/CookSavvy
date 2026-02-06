//
//  LLMModels.swift
//  CookSavvy
//

import Foundation

struct LLMMessage {
    enum Role: String, Codable {
        case system
        case user
        case assistant
    }
    
    let role: Role
    let content: String
}

struct LLMVisionContent {
    let imageData: Data
    let mimeType: String
    let prompt: String
    
    var base64EncodedImage: String {
        imageData.base64EncodedString()
    }
}

enum LLMResponseFormat {
    case text
    case json
}

struct LLMResponse {
    let content: String
    let tokensUsed: TokenUsage?
}

struct TokenUsage {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}
