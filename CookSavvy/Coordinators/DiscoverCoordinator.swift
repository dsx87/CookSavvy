//
//  DiscoverCoordinator.swift
//  CookSavvy
//

import SwiftUI

/// Coordinator for the Discover tab, managing the ingredient-selection → recipe-results →
/// recipe-detail navigation stack and all associated sheet and full-screen cover presentations.
///
/// Owns a `NavigationPath` for push destinations (recipe detail, recipe list) and separate
/// published properties for the active sheet and full-screen cover. Factory methods construct
/// view models for every destination, injecting services from `AppContainer`.
@MainActor
final class DiscoverCoordinator: ObservableObject, RecipeDetailsCoordinating, RecipeListCoordinating {

    private let container: AppContainer
    /// Initial ingredients to pre-select in the Discover view, forwarded from a successful onboarding camera scan.
    private let initialIngredients: [Ingredient]?
    /// Navigation stack path for push destinations (recipe detail, recipe list).
    @Published var navigationPath = NavigationPath()
    /// The currently presented sheet destination, if any.
    @Published var presentedSheet: SheetDestination?
    /// The currently presented full-screen cover destination, if any.
    @Published var presentedFullScreenCover: FullScreenCoverDestination?

    /// - Parameters:
    ///   - container: The shared app DI container.
    ///   - initialIngredients: Optional pre-selected ingredients forwarded from onboarding.
    init(container: AppContainer, initialIngredients: [Ingredient]? = nil) {
        self.container = container
        self.initialIngredients = initialIngredients
    }
    
    /// Builds and returns the root coordinator view for the Discover tab.
    func start() -> some View {
        DiscoverCoordinatorView(coordinator: self)
    }

    // MARK: - Factory Methods

    /// Creates a `RecipeDetailsViewModel` for a pushed recipe detail destination.
    func makeRecipeDetailsViewModel(recipe: Recipe, selectedIngredients: [Ingredient] = []) -> RecipeDetailsViewModel {
        RecipeDetailsViewModel(
            recipe: recipe,
            selectedIngredients: selectedIngredients,
            userDataService: container.userDataService,
            shoppingListService: container.shoppingListService,
            subscriptionService: container.subscriptionService,
            shareCardGenerator: container.recipeShareCardGenerator,
            analyticsService: container.analyticsService,
            logger: container.loggingService.makeLogger(category: .recipeDetailsViewModel),
            coordinator: self
        )
    }

    /// Creates a `ShoppingListViewModel` that dismisses the sheet on completion.
    func makeShoppingListViewModel() -> ShoppingListViewModel {
        ShoppingListViewModel(
            shoppingListService: container.shoppingListService,
            logger: container.loggingService.makeLogger(category: .shoppingListViewModel),
            onDismiss: { [weak self] in self?.dismissSheet() }
        )
    }
    
    /// Creates a `CameraViewModel` wired to toggle detected ingredients in the Discover view.
    ///
    /// - Parameters:
    ///   - onDismiss: Called when the user dismisses the camera.
    ///   - onIngredientsDetected: Called with the detected ingredients; each is toggled in the Discover selection.
    func makeCameraViewModel(
        onDismiss: @escaping () -> Void,
        onIngredientsDetected: @escaping ([Ingredient]) -> Void
    ) -> CameraViewModel {
        CameraViewModel(
            detectionService: container.ingredientDetectionService,
            onDismiss: onDismiss,
            onIngredientsDetected: onIngredientsDetected
        )
    }
    
    /// Creates an `UpgradeViewModel` that dismisses the sheet on completion.
    func makeUpgradeViewModel() -> UpgradeViewModel {
        UpgradeViewModel(
            subscriptionService: container.subscriptionService,
            analyticsService: container.analyticsService,
            onDismiss: { [weak self] in
                self?.dismissSheet()
            }
        )
    }

    /// Creates a `CreateRecipeViewModel` that dismisses the sheet on save or cancel.
    func makeCreateRecipeViewModel() -> CreateRecipeViewModel {
        CreateRecipeViewModel(
            userDataService: container.userDataService,
            onDismiss: { [weak self] in
                self?.dismissSheet()
            }
        )
    }

    /// Creates the `DiscoverViewModel`, passing any initial ingredients and the coordinator reference.
    func makeDiscoverViewModel() -> DiscoverViewModel {
        DiscoverViewModel(
            ingredientsService: container.ingredientsService,
            recipeService: container.recipeService,
            userDataService: container.userDataService,
            subscriptionService: container.subscriptionService,
            databaseInitService: container.databaseInitService,
            cameraScanTracker: container.cameraScanTracker,
            recommendationService: container.recommendationService,
            analyticsService: container.analyticsService,
            logger: container.loggingService.makeLogger(category: .discoverViewModel),
            dietaryPreferences: container.dietaryPreferences,
            curatedCollectionService: container.curatedCollectionService,
            initialIngredients: initialIngredients,
            coordinator: self
        )
    }

    /// Creates a `RecipeListViewModel` for a pushed recipe list destination.
    func makeRecipeListViewModel(title: String, recipes: [Recipe]) -> RecipeListViewModel {
        RecipeListViewModel(
            title: title,
            recipes: recipes,
            userDataService: container.userDataService,
            logger: container.loggingService.makeLogger(category: .recipeListViewModel),
            coordinator: self
        )
    }

    /// Creates a `CookModeViewModel` that dismisses the full-screen cover on exit.
    func makeCookModeViewModel(recipe: Recipe) -> CookModeViewModel {
        CookModeViewModel(
            recipe: recipe,
            userDataService: container.userDataService,
            analyticsService: container.analyticsService,
            logger: container.loggingService.makeLogger(category: .cookModeViewModel),
            onDismiss: { [weak self] in
                self?.dismissFullScreenCover()
            }
        )
    }
    
    // MARK: - Navigation

    /// Pushes a recipe detail destination onto the navigation stack.
    func showRecipeDetails(recipe: Recipe, selectedIngredients: [Ingredient] = []) {
        navigationPath.append(NavigationDestination.recipeDetail(recipe, selectedIngredients: selectedIngredients))
    }
    
    /// Pushes a recipe list destination onto the navigation stack.
    func showRecipeList(title: String, recipes: [Recipe]) {
        navigationPath.append(NavigationDestination.recipeList(title: title, recipes: recipes))
    }

    /// Pushes a recipe detail for a recipe selected from a list.
    func showRecipeFromList(_ recipe: Recipe) {
        showRecipeDetails(recipe: recipe)
    }

    /// Presents the cook mode flow as a full-screen cover.
    func showCookMode(recipe: Recipe) {
        presentedFullScreenCover = .cookMode(recipe)
    }

    /// Presents the camera as a full-screen cover.
    func showCamera() {
        presentedFullScreenCover = .camera
    }

    /// Presents the upgrade sheet.
    func showUpgrade() {
        presentedSheet = .upgrade
    }

    /// Presents the shopping list sheet.
    func showShoppingList() {
        presentedSheet = .shoppingList
    }

    /// Presents the create recipe sheet.
    func showCreateRecipe() {
        presentedSheet = .createRecipe
    }

    /// Pops the top destination from the navigation stack.
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    /// Dismisses the active sheet or full-screen cover.
    func dismissSheet() {
        presentedSheet = nil
        presentedFullScreenCover = nil
    }

    /// Dismisses the active full-screen cover.
    func dismissFullScreenCover() {
        presentedFullScreenCover = nil
    }
}

// MARK: - Destinations

/// Destination enums owned by ``DiscoverCoordinator``.
extension DiscoverCoordinator {
    /// Push destinations managed by the Discover navigation stack.
    enum NavigationDestination: Hashable {
        /// Recipe detail view for the given recipe and pre-selected ingredients.
        case recipeDetail(Recipe, selectedIngredients: [Ingredient])
        /// Paginated recipe list with the given title and recipes.
        case recipeList(title: String, recipes: [Recipe])
    }

    /// Sheet destinations presented over the Discover tab.
    enum SheetDestination: Identifiable {
        /// CookSavvy+ upgrade prompt.
        case upgrade
        /// Create recipe wizard.
        case createRecipe
        /// Shopping list management.
        case shoppingList

        var id: String {
            switch self {
            case .upgrade: return "upgrade"
            case .createRecipe: return "createRecipe"
            case .shoppingList: return "shoppingList"
            }
        }
    }

    /// Full-screen cover destinations for the Discover tab.
    enum FullScreenCoverDestination: Identifiable {
        /// Camera capture for AI ingredient detection.
        case camera
        /// Step-by-step cook mode for the given recipe.
        case cookMode(Recipe)

        var id: String {
            switch self {
            case .camera: return "camera"
            case .cookMode(let recipe): return "cookMode_\(recipe.id)"
            }
        }
    }
}

// MARK: - Coordinator View

/// Internal SwiftUI coordinator view that hosts the Discover navigation stack and applies
/// full-screen cover and sheet presentations driven by `DiscoverCoordinator`.
struct DiscoverCoordinatorView: View {
    @ObservedObject var coordinator: DiscoverCoordinator
    @StateObject private var discoverViewModel: DiscoverViewModel
    
    /// Creates the coordinator view and pins the root `DiscoverViewModel` as a state object.
    init(coordinator: DiscoverCoordinator) {
        self.coordinator = coordinator
        _discoverViewModel = StateObject(wrappedValue: coordinator.makeDiscoverViewModel())
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            DiscoverView(viewModel: discoverViewModel)
                .navigationDestination(for: DiscoverCoordinator.NavigationDestination.self) { destination in
                    switch destination {
                    case .recipeDetail(let recipe, let selectedIngredients):
                        RecipeDetailsView(
                            viewModel: coordinator.makeRecipeDetailsViewModel(recipe: recipe, selectedIngredients: selectedIngredients)
                        )
                    case .recipeList(let title, let recipes):
                        RecipeListView(
                            viewModel: coordinator.makeRecipeListViewModel(title: title, recipes: recipes)
                        )
                    }
                }
        }
        .fullScreenCover(
            item: $coordinator.presentedFullScreenCover,
            onDismiss: {
                coordinator.navigationPath = NavigationPath()
                discoverViewModel.showResults = false
            }
        ) { destination in
            switch destination {
            case .camera:
                CameraView(
                    viewModel: coordinator.makeCameraViewModel(
                        onDismiss: { coordinator.dismissSheet() },
                        onIngredientsDetected: { ingredients in
                            for ingredient in ingredients {
                                discoverViewModel.toggleIngredient(ingredient)
                            }
                        }
                    )
                )
            case .cookMode(let recipe):
                CookModeView(
                    viewModel: coordinator.makeCookModeViewModel(recipe: recipe)
                )
            }
        }
        .sheet(item: $coordinator.presentedSheet) { sheet in
            switch sheet {
            case .upgrade:
                UpgradeView(viewModel: coordinator.makeUpgradeViewModel())
            case .createRecipe:
                CreateRecipeView(viewModel: coordinator.makeCreateRecipeViewModel())
            case .shoppingList:
                ShoppingListView(viewModel: coordinator.makeShoppingListViewModel())
            }
        }
    }
}
