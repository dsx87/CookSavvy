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
    let loggingService: LoggingServiceProtocol
    let authService: AuthServiceProtocol
    let signInWithAppleAction: SignInWithAppleActionProtocol
    let dietaryPreferences: DietaryPreferences
    let curatedCollectionService: CuratedCollectionServiceProtocol

    // MARK: - Initialization

    /// Creates the app-wide singleton-backed container.
    ///
    /// This initializer remains internal for the current singleton lifecycle. Avoid constructing
    /// additional app containers outside the composition root or focused tests; each container owns
    /// independent service instances and database connections.
    internal init() throws {
        let loggingService = LoggingService()
        self.loggingService = loggingService

        #if DEBUG
        let analyticsService: AnalyticsServiceProtocol = MockAnalyticsService()
        #else
        let analyticsService: AnalyticsServiceProtocol = AnalyticsService()
        #endif
        self.analyticsService = analyticsService

        let db = try DBInterface()
        self.dbInterface = db

        let ingredients = IngredientsService(dbInterface: db)
        let dataImport = DataImportService(
            dbInterface: db,
            logger: loggingService.makeLogger(category: .dataImportService)
        )
        
        self.ingredientsService = ingredients
        self.imageService = ImageService()
        self.dataImportService = dataImport
        self.userDataService = UserDataService(dbInterface: db)
        
        let network = NetworkService()
        self.networkService = network
        
        let supabaseAssembly = SupabaseServiceAssembly()
        let recipeAPIProvider = supabaseAssembly.recipeAPIProvider
        let llmProvider = supabaseAssembly.llmProvider

        if let clientProvider = supabaseAssembly.clientProvider {
            self.authService = SupabaseAuthService(
                clientProvider: clientProvider,
                analyticsService: analyticsService,
                logger: loggingService.makeLogger(category: .authService)
            )
        } else {
            #if DEBUG
            self.authService = MockAuthService(
                initialState: .signedIn(userId: "mock-user"),
                analyticsService: analyticsService
            )
            #else
            self.authService = NoOpAuthService()
            #endif
        }

        #if DEBUG
        let appleSignInManager: any AppleSignInManaging = supabaseAssembly.clientProvider == nil
            ? MockAppleSignInManager()
            : AppleSignInManager()
        #else
        let appleSignInManager: any AppleSignInManaging = AppleSignInManager()
        #endif
        self.signInWithAppleAction = SignInWithAppleAction(
            authService: self.authService,
            analyticsService: analyticsService,
            logger: loggingService.makeLogger(category: .authService),
            appleSignInManager: appleSignInManager
        )

        let ai = AIService(provider: llmProvider)
        self.aiService = ai
        self.ingredientDetectionService = AIIngredientDetectionAdapter(aiService: ai)

        let onlineSource = OnlineRecipeSource(provider: recipeAPIProvider)
        self.recipeService = RecipeService(
            dbInterface: db,
            sources: [
                .offline: OfflineRecipeSource(dbInterface: db),
                .online: onlineSource,
                .ai: AIRecipeSource(aiService: ai)
            ],
            logger: loggingService.makeLogger(category: .recipeService)
        )

        self.databaseInitService = DatabaseInitializationService(
            dbInterface: db,
            ingredientsService: ingredients,
            dataImportService: dataImport
        )
        
        #if DEBUG
        self.subscriptionService = MockSubscriptionService(initialPlan: .free)
        #else
        self.subscriptionService = StoreKitSubscriptionService(
            logger: loggingService.makeLogger(category: .subscriptionService)
        )
        #endif

        self.cameraScanTracker = CameraScanTracker()
        self.shoppingListService = ShoppingListService(dbInterface: db)
        self.recommendationService = RecipeRecommendationService(
            userDataService: self.userDataService,
            dbInterface: db,
            databaseInitService: self.databaseInitService
        )

        databaseInitService.startInitialization()

        self.dietaryPreferences = DietaryPreferences(
            logger: loggingService.makeLogger(category: .dietaryPreferences)
        )
        self.curatedCollectionService = CuratedCollectionService(dbInterface: db)
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
        recommendationService: RecipeRecommendationServiceProtocol,
        loggingService: LoggingServiceProtocol,
        authService: AuthServiceProtocol,
        analyticsService: AnalyticsServiceProtocol = MockAnalyticsService(),
        signInWithAppleAction: SignInWithAppleActionProtocol? = nil
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
        self.analyticsService = analyticsService
        self.loggingService = loggingService
        self.authService = authService
        self.signInWithAppleAction = signInWithAppleAction ?? SignInWithAppleAction(
            authService: authService,
            analyticsService: analyticsService,
            logger: loggingService.makeLogger(category: .authService),
            appleSignInManager: MockAppleSignInManager()
        )
        self.dietaryPreferences = DietaryPreferences(
            logger: loggingService.makeLogger(category: .dietaryPreferences)
        )
        self.curatedCollectionService = CuratedCollectionService(dbInterface: dbInterface)
    }
    #endif

    #if DEBUG
    @MainActor
    static func makeInMemory(
        subscriptionPlan: SubscriptionPlan = .free,
        authState: AuthState = .signedIn(userId: "mock-anonymous-user"),
        isAnonymous: Bool = true
    ) throws -> AppContainer {
        let loggingService = LoggingService()
        let db = try DBInterface(inMemory: true)
        let ingredients = IngredientsService(dbInterface: db)
        let dataImport = DataImportService(
            dbInterface: db,
            logger: loggingService.makeLogger(category: .dataImportService)
        )
        let network = NetworkService()
        let userDataService = UserDataService(dbInterface: db)
        let llmProvider: LLMProviderProtocol = MockLLMProvider()
        let ai = AIService(provider: llmProvider)
        let onlineSource = OnlineRecipeSource(provider: nil)
        let recipeService = RecipeService(
            dbInterface: db,
            sources: [
                .offline: OfflineRecipeSource(dbInterface: db),
                .online: onlineSource,
                .ai: AIRecipeSource(aiService: ai)
            ],
            logger: loggingService.makeLogger(category: .recipeService)
        )
        let databaseInitService = DatabaseInitializationService(
            dbInterface: db,
            ingredientsService: ingredients,
            dataImportService: dataImport
        )
        let analyticsService = MockAnalyticsService()

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
            ),
            loggingService: loggingService,
            authService: MockAuthService(
                initialState: authState,
                isAnonymous: isAnonymous,
                analyticsService: analyticsService
            ),
            analyticsService: analyticsService
        )

        databaseInitService.markReadyForTesting()
        return container
    }

    @MainActor
    static func configureForUITesting(_ config: UITestConfiguration) throws -> AppContainer {
        let subscriptionPlan: SubscriptionPlan = config.isPremiumUser ? .premium : .free
        let container = try makeInMemory(
            subscriptionPlan: subscriptionPlan,
            authState: config.isSignedInWithApple
                ? .signedIn(userId: "mock-apple-user")
                : .signedIn(userId: "mock-anonymous-user"),
            isAnonymous: !config.isSignedInWithApple
        )

        UITestDataSeeder(db: container.dbInterface).seed(config: config)
        return container
    }
    #endif

    func handleSceneBecameActive() async {
        async let authRefresh: Void = authService.startSessionIfNeeded()
        async let subscriptionRefresh: Void = subscriptionService.refreshSubscriptionStatus()
        _ = await (authRefresh, subscriptionRefresh)
    }
}
