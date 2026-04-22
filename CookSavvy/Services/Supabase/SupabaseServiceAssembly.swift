//
//  SupabaseServiceAssembly.swift
//  CookSavvy
//

import Foundation

/// Factory that reads Supabase credentials and wires up all Supabase-backed services.
///
/// When Supabase is not configured (missing or empty URL / anon key), all optional
/// service properties are set to `nil` at construction time, causing the app to operate
/// in offline-only mode without AI or online recipe features.
///
/// Called once from `AppContainer` at startup. The `clientProviderFactory` closure allows
/// injecting a mock `SupabaseClientProvider` in tests without hitting the network.
struct SupabaseServiceAssembly {
    /// The Supabase configuration read from `APIKeys.plist`.
    let configuration: SupabaseConfiguration
    /// The Supabase client provider, or `nil` when Supabase is not configured.
    let clientProvider: SupabaseClientProviderProtocol?
    /// The LLM provider backed by Supabase Edge Functions, or `nil` when Supabase is not configured.
    let llmProvider: LLMProviderProtocol?
    /// The recipe API provider backed by Supabase Edge Functions, or `nil` when Supabase is not configured.
    let recipeAPIProvider: RecipeAPIProviderProtocol?

    /// Reads `SupabaseConfiguration` from the given bundle and assembles services.
    /// - Parameters:
    ///   - bundle: Bundle to read `APIKeys.plist` from. Defaults to `.main`.
    ///   - clientProviderFactory: Closure that creates the `SupabaseClientProvider`; injectable for tests.
    init(
        bundle: Bundle = .main,
        clientProviderFactory: (URL, String) -> SupabaseClientProviderProtocol = {
            SupabaseClientProvider(projectURL: $0, anonKey: $1)
        }
    ) {
        self.init(
            configuration: SupabaseConfiguration(bundle: bundle),
            clientProviderFactory: clientProviderFactory
        )
    }

    /// Assembles services from an already-resolved `SupabaseConfiguration`.
    ///
    /// If the configuration is incomplete (no URL or empty anon key), all service properties
    /// are set to `nil` and initialization returns early — no `SupabaseClient` is created.
    /// - Parameters:
    ///   - configuration: Pre-built configuration; enables testing with arbitrary credentials.
    ///   - clientProviderFactory: Closure that creates the `SupabaseClientProvider`; injectable for tests.
    init(
        configuration: SupabaseConfiguration,
        clientProviderFactory: (URL, String) -> SupabaseClientProviderProtocol = {
            SupabaseClientProvider(projectURL: $0, anonKey: $1)
        }
    ) {
        self.configuration = configuration

        guard
            let projectURL = configuration.projectURL,
            let anonKey = configuration.anonKey,
            !anonKey.isEmpty
        else {
            self.clientProvider = nil
            self.llmProvider = nil
            self.recipeAPIProvider = nil
            return
        }

        let clientProvider = clientProviderFactory(projectURL, anonKey)
        self.clientProvider = clientProvider
        self.llmProvider = SupabaseLLMProvider(clientProvider: clientProvider)
        self.recipeAPIProvider = SupabaseRecipeAPIProvider(
            clientProvider: clientProvider,
            configuration: configuration
        )
    }
}
