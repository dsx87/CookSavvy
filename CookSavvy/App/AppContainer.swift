//
//  AppContainer.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import Foundation

/// Dependency injection container holding shared service instances

@MainActor
final class AppContainer {

    // TODO: redo this in non singleton way
    static let shared: AppContainer = AppContainer()
    
    // MARK: - Services
    let dbInterface: DBInterfaceProtocol
    let ingredientsService: IngredientsServiceProtocol
    let recipeService: RecipeServiceProtocol
    let imageService: ImageServiceProtocol
    let dataImportService: DataImportServiceProtocol
    let userDataService: UserDataServiceProtocol
    let databaseInitService: DatabaseInitializationServiceProtocol
    let networkService: NetworkServiceProtocol
    let aiService: AIServiceProtocol
    let ingredientDetectionService: IngredientDetectionServiceProtocol
    let subscriptionService: SubscriptionServiceProtocol
    let cameraScanTracker: CameraScanTrackerProtocol
    let shoppingListService: ShoppingListServiceProtocol
    let recommendationService: RecipeRecommendationServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let dietaryPreferences: DietaryPreferences

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
        
        let llmProvider: LLMProviderProtocol
        #if DEBUG
        llmProvider = MockLLMProvider()
        #else
        llmProvider = Self.createProductionProvider(networkService: network)
        #endif
        let ai = AIService(provider: llmProvider)
        self.aiService = ai
        self.ingredientDetectionService = AIIngredientDetectionAdapter(aiService: ai)

        let recipeAPIProvider = Self.createRecipeAPIProvider(networkService: network)
        let onlineSource = OnlineRecipeSource(provider: recipeAPIProvider)
        self.recipeService = RecipeService(
            dbInterface: db,
            sources: [
                .offline: OfflineRecipeSource(dbInterface: db),
                .online: onlineSource,
                .ai: AIRecipeSource(aiService: ai)
            ]
        )

        self.databaseInitService = DatabaseInitializationService(
            dbInterface: db,
            ingredientsService: ingredients,
            dataImportService: dataImport
        )
        
        #if DEBUG
        self.subscriptionService = MockSubscriptionService(initialPlan: .free)
        #else
        self.subscriptionService = StoreKitSubscriptionService()
        #endif

        self.cameraScanTracker = CameraScanTracker()
        self.shoppingListService = ShoppingListService(dbInterface: db)
        self.recommendationService = RecipeRecommendationService(
            userDataService: self.userDataService,
            dbInterface: db,
            databaseInitService: self.databaseInitService
        )

        databaseInitService.startInitialization()

        #if DEBUG
        self.analyticsService = MockAnalyticsService()
        #else
        self.analyticsService = AnalyticsService()
        #endif
        self.dietaryPreferences = DietaryPreferences()
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
