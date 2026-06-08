import Foundation

/// Parses a natural-language query into a `SmartSearchIntent` using an AI provider.
protocol SmartSearchServiceProtocol {
    func parse(query: String) async throws -> SmartSearchIntent
}

/// A single AI backend capable of parsing a query into structured intent.
/// Implementations: `FoundationModelsSmartSearchProvider` (iOS 26, on-device) and
/// `SupabaseSmartSearchProvider` (Supabase edge function fallback).
protocol SmartSearchProviderProtocol {
    func parse(query: String) async throws -> SmartSearchIntent
}

/// Errors surfaced by the smart-search layer.
enum SmartSearchError: Error {
    /// The LLM model refused the request or returned content that couldn't be parsed.
    case parsingFailed(String?)
    /// A network or edge-function error occurred.
    case networkError(Error)
}
