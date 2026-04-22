//
//  LLMModels.swift
//  CookSavvy
//

import Foundation

/// A single turn in a multi-message chat conversation sent to an LLM.
struct LLMMessage {
    /// Conversation participant roles mirroring the OpenAI / Gemini message role conventions.
    enum Role: String, Codable {
        /// Sets behavioural instructions for the model (e.g., "You are a chef assistant").
        case system
        /// The end-user's input or question.
        case user
        /// A prior model-generated reply (used for multi-turn history).
        case assistant
    }
    
    /// The participant sending this message.
    let role: Role
    /// Text content of the message.
    let content: String
}

/// Bundles the raw image bytes and associated metadata needed to build a vision request payload.
struct LLMVisionContent {
    /// Raw bytes of the image to analyse.
    let imageData: Data
    /// MIME type of the image, e.g. `"image/jpeg"`.
    let mimeType: String
    /// Text instruction accompanying the image.
    let prompt: String
    
    /// Base64 representation of `imageData`, used when embedding the image in a JSON payload.
    var base64EncodedImage: String {
        imageData.base64EncodedString()
    }
}

/// Instructs the LLM on how to format its output.
enum LLMResponseFormat {
    /// Return unstructured natural-language text.
    case text
    /// Return a valid JSON object. Providers should set the appropriate response-format header
    /// or generation config to enforce this.
    case json
}

/// The normalised response returned by any `LLMProviderProtocol` implementation.
struct LLMResponse {
    /// The raw text (or JSON string) produced by the model.
    let content: String
    /// Token consumption reported by the API, if available. May be `nil` for providers that
    /// do not expose usage metadata.
    let tokensUsed: TokenUsage?
}

/// Token counts reported by the LLM API for a single request/response cycle.
struct TokenUsage {
    /// Tokens consumed by the input (prompt + image encoding).
    let promptTokens: Int
    /// Tokens generated in the model's response.
    let completionTokens: Int
    /// Sum of `promptTokens` and `completionTokens`. Some APIs report this directly;
    /// others require the caller to compute it.
    let totalTokens: Int
}
