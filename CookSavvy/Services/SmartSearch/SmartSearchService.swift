import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Routes smart-search queries to the best available AI provider.
///
/// Provider selection at construction time:
/// - **iOS 26+ with Apple Intelligence on**: `FoundationModelsSmartSearchProvider` (on-device, no network).
/// - **Anything else**: `makeIfAvailable` returns `nil` and the Smart Search row is hidden from the UI.
///
/// `EdgeFunctionSmartSearchProvider` exists as a planned fallback for older devices but is not wired
/// until the `parse-search-query` Supabase edge function is deployed. See wiring note below.
final class SmartSearchService: SmartSearchServiceProtocol {
    private let provider: any SmartSearchProviderProtocol

    init(provider: any SmartSearchProviderProtocol) {
        self.provider = provider
    }

    /// Creates a service with the best available provider, or `nil` when no working provider exists.
    ///
    /// Currently only the on-device Foundation Models path is exposed. The `EdgeFunctionSmartSearchProvider`
    /// code exists but is not wired here until the `parse-search-query` Supabase edge function is deployed —
    /// exposing a provider that predictably fails would show a Smart Search row to non-iOS-26 users that
    /// always errors. Wire the edge function path here once the backend function is live.
    static func makeIfAvailable(clientProvider: SupabaseClientProviderProtocol?) -> SmartSearchServiceProtocol? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if SystemLanguageModel.default.isAvailable {
                return SmartSearchService(provider: FoundationModelsSmartSearchProvider())
            }
        }
        #endif
        return nil
    }

    func parse(query: String) async throws -> SmartSearchIntent {
        try await provider.parse(query: query)
    }
}
