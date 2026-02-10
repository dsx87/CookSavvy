//
//  AppContainer.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import Foundation
import os

/// Dependency injection container holding shared service instances

@MainActor
final class AppContainer {

    // TODO: redo this in non singleton way
    static let shared: AppContainer = AppContainer()
    
    // MARK: - Services
    let dbInterface: DBInterfaceProtocol
    let ingredientsService: IngredientsService
    let recipeService: RecipeService
    let imageService: ImageService
    let dataImportService: DataImportService
    let userDataService: UserDataService
    let databaseInitService: DatabaseInitializationService
    let networkService: NetworkServiceProtocol
    let aiService: AIServiceProtocol
    let ingredientDetectionService: IngredientDetectionServiceProtocol
    let subscriptionService: SubscriptionServiceProtocol

    // MARK: - Initialization

    private init() {
        let db = DBInterface()
        self.dbInterface = db

        let ingredients = IngredientsService(dbInterface: db)
        let dataImport = DataImportService(dbInterface: db)
        
        self.ingredientsService = ingredients
        self.imageService = ImageService()
        self.dataImportService = dataImport
        self.userDataService = UserDataService(dbInterface: db)
        
        let network = NetworkService()
        self.networkService = network
        
        let recipeAPIProvider = Self.createRecipeAPIProvider(networkService: network)
        let onlineSource = OnlineRecipeSource(provider: recipeAPIProvider)
        self.recipeService = RecipeService(
            dbInterface: db,
            sources: [
                .offline: OfflineRecipeSource(dbInterface: db),
                .online: onlineSource,
                .ai: AIRecipeSource()
            ]
        )
        
        self.databaseInitService = DatabaseInitializationService(
            dbInterface: db,
            ingredientsService: ingredients,
            dataImportService: dataImport
        )

        let llmProvider: LLMProviderProtocol
        #if DEBUG
        llmProvider = MockLLMProvider()
        #else
        llmProvider = Self.createProductionProvider(networkService: network)
        #endif
        let ai = AIService(provider: llmProvider)
        self.aiService = ai
        self.ingredientDetectionService = AIIngredientDetectionAdapter(aiService: ai)
        
        #if DEBUG
        self.subscriptionService = MockSubscriptionService(initialPlan: .free)
        #else
        self.subscriptionService = StoreKitSubscriptionService()
        #endif
        
        databaseInitService.startInitialization()
    }
    
    private static func createRecipeAPIProvider(networkService: NetworkServiceProtocol) -> RecipeAPIProviderProtocol? {
        guard let key = APIKeyConfiguration.spoonacularKey, !key.isEmpty else {
            return nil
        }
        return SpoonacularProvider(apiKey: key, networkService: networkService)
    }
    
    private static func createProductionProvider(networkService: NetworkServiceProtocol) -> LLMProviderProtocol {
        if let openAIKey = APIKeyConfiguration.openAIKey, !openAIKey.isEmpty {
            return OpenAIProvider(apiKey: openAIKey, networkService: networkService)
        } else if let geminiKey = APIKeyConfiguration.geminiKey, !geminiKey.isEmpty {
            return GeminiProvider(apiKey: geminiKey, networkService: networkService)
        }
        
        return MockLLMProvider()
    }
}

enum APIKeyConfiguration {
    private static let plistName = "APIKeys"
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "APIKeyConfiguration"
    )
    
    static var openAIKey: String? {
        getValue(for: "OPENAI_API_KEY")
    }
    
    static var geminiKey: String? {
        getValue(for: "GEMINI_API_KEY")
    }
    
    static var spoonacularKey: String? {
        getValue(for: "SPOONACULAR_API_KEY")
    }
    
    private static func getValue(for key: String) -> String? {
        guard let path = Bundle.main.path(forResource: plistName, ofType: "plist") else {
            logger.warning("APIKeys.plist not found in app bundle. AI provider keys unavailable.")
            return nil
        }
        guard let dict = NSDictionary(contentsOfFile: path) else {
            logger.warning("APIKeys.plist could not be read. AI provider keys unavailable.")
            return nil
        }
        guard let value = dict[key] as? String, !value.isEmpty else {
            return nil
        }
        return value
    }
}
