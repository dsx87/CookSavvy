//
//  SupabaseServiceAssembly.swift
//  CookSavvy
//

import Foundation

struct SupabaseServiceAssembly {
    let configuration: SupabaseConfiguration
    let clientProvider: SupabaseClientProviderProtocol?
    let llmProvider: LLMProviderProtocol?
    let recipeAPIProvider: RecipeAPIProviderProtocol?

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
