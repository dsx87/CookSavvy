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
    #if DEBUG
    static private(set) var shared: AppContainer = AppContainer()
    #else
    static let shared: AppContainer = AppContainer()
    #endif
    
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

        self.cameraScanTracker = CameraScanTracker()
        self.shoppingListService = ShoppingListService(dbInterface: db)
        self.recommendationService = RecipeRecommendationService(
            userDataService: self.userDataService,
            dbInterface: db,
            databaseInitService: self.databaseInitService
        )

        databaseInitService.startInitialization()
    }

    #if DEBUG
    private init(
        dbInterface: DBInterfaceProtocol,
        ingredientsService: IngredientsServiceProtocol,
        recipeService: RecipeServiceProtocol,
        imageService: ImageServiceProtocol,
        dataImportService: DataImportServiceProtocol,
        userDataService: UserDataServiceProtocol,
        databaseInitService: DatabaseInitializationServiceProtocol,
        networkService: NetworkServiceProtocol,
        aiService: AIServiceProtocol,
        ingredientDetectionService: IngredientDetectionServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        cameraScanTracker: CameraScanTrackerProtocol,
        shoppingListService: ShoppingListServiceProtocol,
        recommendationService: RecipeRecommendationServiceProtocol
    ) {
        self.dbInterface = dbInterface
        self.ingredientsService = ingredientsService
        self.recipeService = recipeService
        self.imageService = imageService
        self.dataImportService = dataImportService
        self.userDataService = userDataService
        self.databaseInitService = databaseInitService
        self.networkService = networkService
        self.aiService = aiService
        self.ingredientDetectionService = ingredientDetectionService
        self.subscriptionService = subscriptionService
        self.cameraScanTracker = cameraScanTracker
        self.shoppingListService = shoppingListService
        self.recommendationService = recommendationService
    }
    #endif

    private static func createRecipeAPIProvider(networkService: NetworkServiceProtocol) -> RecipeAPIProviderProtocol? {
        guard let key = APIKeyConfiguration.spoonacularKey, !key.isEmpty else {
            return nil
        }
        return SpoonacularProvider(apiKey: key, networkService: networkService)
    }
    
    #if DEBUG
    @MainActor
    static func configureForUITesting(_ config: UITestConfiguration) {
        let db = DBInterface(inMemory: true)
        let ingredients = IngredientsService(dbInterface: db)
        let dataImport = DataImportService(dbInterface: db)
        let network = NetworkService()
        let userDataService = UserDataService(dbInterface: db)
        let onlineSource = OnlineRecipeSource(provider: nil)
        let recipeService = RecipeService(
            dbInterface: db,
            sources: [
                .offline: OfflineRecipeSource(dbInterface: db),
                .online: onlineSource,
                .ai: AIRecipeSource()
            ]
        )
        let databaseInitService = DatabaseInitializationService(
            dbInterface: db,
            ingredientsService: ingredients,
            dataImportService: dataImport
        )
        let llmProvider: LLMProviderProtocol = MockLLMProvider()
        let ai = AIService(provider: llmProvider)
        let subscriptionPlan: SubscriptionPlan = config.isPremiumUser ? .premium : .free

        let container = AppContainer(
            dbInterface: db,
            ingredientsService: ingredients,
            recipeService: recipeService,
            imageService: ImageService(),
            dataImportService: dataImport,
            userDataService: userDataService,
            databaseInitService: databaseInitService,
            networkService: network,
            aiService: ai,
            ingredientDetectionService: AIIngredientDetectionAdapter(aiService: ai),
            subscriptionService: MockSubscriptionService(initialPlan: subscriptionPlan),
            cameraScanTracker: CameraScanTracker(),
            shoppingListService: ShoppingListService(dbInterface: db),
            recommendationService: RecipeRecommendationService(
                userDataService: userDataService,
                dbInterface: db,
                databaseInitService: databaseInitService
            )
        )

        UITestDataSeeder(db: db).seed(config: config)
        databaseInitService.markReadyForTesting()

        AppContainer.shared = container
    }
    #endif

    private static func createProductionProvider(networkService: NetworkServiceProtocol) -> LLMProviderProtocol {
        if let openAIKey = APIKeyConfiguration.openAIKey, !openAIKey.isEmpty {
            return OpenAIProvider(apiKey: openAIKey, networkService: networkService)
        } else if let geminiKey = APIKeyConfiguration.geminiKey, !geminiKey.isEmpty {
            return GeminiProvider(apiKey: geminiKey, networkService: networkService)
        }
        
        return MockLLMProvider()
    }
}
