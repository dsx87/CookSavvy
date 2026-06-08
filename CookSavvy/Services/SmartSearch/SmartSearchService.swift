import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Routes smart-search queries to the best available AI provider.
///
/// Provider selection at construction time:
/// - **iOS 26+ with Apple Intelligence on**: `FoundationModelsSmartSearchProvider` (on-device, no network).
/// - **Otherwise, when Supabase is configured**: `SupabaseSmartSearchProvider` (DeepSeek via the
///   `parse-search-query` edge function), so Smart Search reaches every user regardless of device/OS.
/// - **Neither available** (Supabase unconfigured): `makeIfAvailable` returns `nil` and the Smart
///   Search row is hidden from the UI.
final class SmartSearchService: SmartSearchServiceProtocol {
    private let provider: any SmartSearchProviderProtocol

    init(provider: any SmartSearchProviderProtocol) {
        self.provider = provider
    }

    /// Creates a service with the best available provider, or `nil` when no working provider exists.
    ///
    /// Prefers the on-device Foundation Models path (iOS 26+, Apple Intelligence) — zero network, fully
    /// private. When that is unavailable, falls back to `SupabaseSmartSearchProvider` (DeepSeek via
    /// the `parse-search-query` edge function) as long as a Supabase client is configured. Returns `nil`
    /// only when neither path is possible, in which case the Smart Search row is hidden.
    static func makeIfAvailable(clientProvider: SupabaseClientProviderProtocol?) -> SmartSearchServiceProtocol? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if SystemLanguageModel.default.isAvailable {
                return SmartSearchService(provider: FoundationModelsSmartSearchProvider())
            }
        }
        #endif
        if let clientProvider {
            return SmartSearchService(provider: SupabaseSmartSearchProvider(clientProvider: clientProvider))
        }
        return nil
    }

    func parse(query: String) async throws -> SmartSearchIntent {
        try await provider.parse(query: query)
    }
}
