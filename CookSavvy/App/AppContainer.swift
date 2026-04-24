//
//  AppContainer.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import Foundation

/// Central dependency injection container that owns all shared service instances for the app.
///
/// `AppContainer` is a `@MainActor` class that wires every service together at startup.
/// Services are created once, stored as protocol-typed properties, and injected into coordinators
/// and view models. Construction is throwing — a database failure or other critical error
/// propagates up and renders a blocking startup error screen instead of allowing the app to
/// continue in a degraded state.
///
/// In DEBUG builds the container can be replaced with an in-memory variant (``makeInMemory``)
/// or a fully deterministic UI-test variant (``configureForUITesting(_:)``).
@MainActor
final class AppContainer {

    // MARK: - Services

    /// GRDB SQLite database layer; the single source of persistent storage for the app.
    let dbInterface: DBInterfaceProtocol
    /// Ingredient search and management backed by the database.
    let ingredientsService: IngredientsServiceProtocol
    /// Recipe search across offline, online, and AI sources.
    let recipeService: RecipeServiceProtocol
    /// Image loading and disk caching.
    let imageService: ImageServiceProtocol
    /// Branded PNG recipe share-card generation.
    let recipeShareCardGenerator: RecipeShareCardGenerating
    /// CSV dataset import into the database.
    let dataImportService: DataImportServiceProtocol
    /// User-specific data — favorites, recent recipes, and cooking sessions.
    let userDataService: UserDataServiceProtocol
    /// Seeds the database on first launch and tracks initialization readiness.
    let databaseInitService: DatabaseInitializationServiceProtocol
    /// Raw HTTP request execution used by network-dependent services.
    let networkService: NetworkServiceProtocol
    /// AI-powered ingredient detection and recipe generation.
    let aiService: AIServiceProtocol
    /// Bridges `AIService` for the camera ingredient-detection flow.
    let ingredientDetectionService: IngredientDetectionServiceProtocol
    /// StoreKit 2 subscription management; `MockSubscriptionService` in DEBUG builds.
    let subscriptionService: SubscriptionServiceProtocol
    /// Tracks free-tier weekly camera scan usage via UserDefaults.
    let cameraScanTracker: CameraScanTrackerProtocol
    /// Shopping list CRUD backed by the database.
    let shoppingListService: ShoppingListServiceProtocol
    /// Personalized recipe suggestions derived from cooking history.
    let recommendationService: RecipeRecommendationServiceProtocol
    /// Event analytics; `MockAnalyticsService` in DEBUG builds, `AnalyticsService` in RELEASE.
    let analyticsService: AnalyticsServiceProtocol
    /// Creates feature-scoped `os.Logger` instances for structured logging.
    let loggingService: LoggingServiceProtocol
    /// Authentication service; Supabase when configured, mock in DEBUG, no-op in RELEASE without keys.
    let authService: AuthServiceProtocol
    /// Orchestrates the Sign in with Apple flow end-to-end.
    let signInWithAppleAction: SignInWithAppleActionProtocol
    /// Persisted user dietary filter settings.
    let dietaryPreferences: DietaryPreferences
    /// Curated recipe collection management backed by the database.
    let curatedCollectionService: CuratedCollectionServiceProtocol

    // MARK: - Initialization

    /// Creates and wires all production services.
    ///
    /// Initialization order matters: logging and analytics are created first so that subsequent
    /// services can receive a logger. The database is opened next since most services depend on it.
    /// Auth is wired conditionally — Supabase when configured, mock in DEBUG, no-op in RELEASE
    /// without keys. `RecipeService` is composed from three pluggable sources (offline, online, AI).
    /// Finally, `databaseInitService.startInitialization()` kicks off asynchronous first-launch
    /// seeding in the background.
    ///
    /// - Throws: Propagates any `DBInterface` initialization error, preventing a partially
    ///   initialized container from being used.
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
        let imageService = ImageService()
        self.imageService = imageService
        self.recipeShareCardGenerator = RecipeShareCardGenerator(imageService: imageService)
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
    /// Designated memberwise initializer used by DEBUG factory methods to inject pre-built services.
    ///
    /// Bypasses the normal construction logic so tests and previews can supply arbitrary
    /// protocol implementations for every dependency.
    private init(
        dbInterface: DBInterfaceProtocol,
        ingredientsService: IngredientsServiceProtocol,
        recipeService: RecipeServiceProtocol,
        imageService: ImageServiceProtocol,
        recipeShareCardGenerator: RecipeShareCardGenerating? = nil,
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
        self.recipeShareCardGenerator = recipeShareCardGenerator ?? RecipeShareCardGenerator(imageService: imageService)
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
    /// Creates an in-memory container suitable for unit tests and SwiftUI previews.
    ///
    /// Uses a transient `DBInterface` and mock implementations for subscription, auth, and AI so
    /// that no persistent state is created or required. `databaseInitService.markReadyForTesting()`
    /// is called synchronously so callers do not need to await initialization.
    ///
    /// - Parameters:
    ///   - subscriptionPlan: The subscription plan to seed into `MockSubscriptionService`.
    ///   - authState: The initial auth state to seed into `MockAuthService`.
    ///   - isAnonymous: Whether the mock user is treated as anonymous.
    /// - Returns: A fully initialized `AppContainer` backed by in-memory storage.
    /// - Throws: `DBInterface` initialization errors (unlikely in in-memory mode).
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

    /// Creates a deterministic container pre-seeded for UI tests based on the supplied configuration.
    ///
    /// Delegates to ``makeInMemory`` then runs ``UITestDataSeeder`` to populate the database
    /// according to the flags present in `config` (cooking history, favorites, shopping items, etc.).
    ///
    /// - Parameter config: Parsed launch-argument configuration from `UITestConfiguration`.
    /// - Returns: A container ready for UI testing.
    /// - Throws: Database initialization errors.
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

    /// Refreshes auth session and subscription status concurrently when the scene becomes active.
    ///
    /// Both tasks are awaited in parallel using `async let` to minimize latency on each activation.
    func handleSceneBecameActive() async {
        async let authRefresh: Void = authService.startSessionIfNeeded()
        async let subscriptionRefresh: Void = subscriptionService.refreshSubscriptionStatus()
        _ = await (authRefresh, subscriptionRefresh)
    }
}
