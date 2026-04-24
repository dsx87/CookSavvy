//
//  JourneyCoordinator.swift
//  CookSavvy
//

import SwiftUI

/// Coordinator for the My Kitchen (Journey) tab, managing saved recipes, recent cooks,
/// shopping list, settings, create recipe, cook mode, and upgrade flows.
///
/// Owns a `NavigationPath` for push destinations and separate published properties for
/// the active sheet and full-screen cover. A `settingsCoordinator` child handles nested
/// settings navigation. Selected ingredients for recipe detail pushes are stored by recipe
/// ID so they survive the navigation lifecycle without being embedded in the enum case.
@MainActor
final class JourneyCoordinator: ObservableObject, JourneyCoordinating, RecipeListCoordinating {

    private let container: AppContainer
    /// Child coordinator responsible for the Settings screen.
    let settingsCoordinator: SettingsCoordinator
    /// Navigation stack path for push destinations (recipe detail, recipe list, settings).
    @Published var navigationPath = NavigationPath()
    /// The currently presented sheet destination, if any.
    @Published var presentedSheet: SheetDestination?
    /// The currently presented full-screen cover destination, if any.
    @Published var presentedFullScreenCover: FullScreenCoverDestination?
    /// Cached selected-ingredient lists keyed by recipe ID, used when pushing recipe detail.
    ///
    /// Stored separately from the `NavigationDestination` enum to avoid embedding large
    /// value types in a `Hashable` enum case.
    private var recipeDetailSelectedIngredients: [String: [Ingredient]] = [:]

    /// - Parameters:
    ///   - container: The shared app DI container.
    ///   - settingsCoordinator: The child coordinator for the Settings screen.
    init(container: AppContainer, settingsCoordinator: SettingsCoordinator) {
        self.container = container
        self.settingsCoordinator = settingsCoordinator
    }
    
    /// Builds and returns the root coordinator view for the My Kitchen tab.
    func start() -> some View {
        JourneyCoordinatorView(coordinator: self)
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

    /// Creates the `JourneyViewModel`, injecting services and the coordinator reference.
    func makeJourneyViewModel() -> JourneyViewModel {
        JourneyViewModel(
            userDataService: container.userDataService,
            subscriptionService: container.subscriptionService,
            cameraScanTracker: container.cameraScanTracker,
            authService: container.authService,
            signInWithAppleAction: container.signInWithAppleAction,
            logger: container.loggingService.makeLogger(category: .journeyViewModel),
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

    /// Caches `selectedIngredients` for `recipe`, then pushes the recipe detail destination.
    func showRecipeDetail(recipe: Recipe, selectedIngredients: [Ingredient] = []) {
        recipeDetailSelectedIngredients[recipe.id] = selectedIngredients
        navigationPath.append(NavigationDestination.recipeDetail(recipe))
    }

    /// Pushes a recipe list destination onto the navigation stack.
    func showRecipeList(title: String, recipes: [Recipe]) {
        navigationPath.append(NavigationDestination.recipeList(title: title, recipes: recipes))
    }

    /// Pushes a recipe detail for a recipe selected from a list.
    func showRecipeFromList(_ recipe: Recipe) {
        showRecipeDetail(recipe: recipe, selectedIngredients: [])
    }

    /// Pushes the settings destination onto the navigation stack.
    func showSettings() {
        navigationPath.append(NavigationDestination.settings)
    }

    /// Presents the create recipe sheet.
    func showCreateRecipe() {
        presentedSheet = .createRecipe
    }

    /// Presents cook mode as a full-screen cover.
    func showCookMode(recipe: Recipe) {
        presentedFullScreenCover = .cookMode(recipe)
    }

    /// Presents the upgrade sheet.
    func showUpgrade() {
        presentedSheet = .upgrade
    }

    /// Presents the shopping list sheet.
    func showShoppingList() {
        presentedSheet = .shoppingList
    }

    /// Pops the top destination from the navigation stack.
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    /// Dismisses the active sheet.
    func dismissSheet() {
        presentedSheet = nil
    }

    /// Dismisses the active full-screen cover.
    func dismissFullScreenCover() {
        presentedFullScreenCover = nil
    }
}

// MARK: - Destinations

/// Destination enums owned by ``JourneyCoordinator``.
extension JourneyCoordinator {
    /// Push destinations managed by the Journey navigation stack.
    enum NavigationDestination: Hashable {
        /// Recipe detail for the given recipe.
        case recipeDetail(Recipe)
        /// Paginated recipe list with the given title and recipes.
        case recipeList(title: String, recipes: [Recipe])
        /// Settings screen.
        case settings
    }

    /// Sheet destinations presented over the My Kitchen tab.
    enum SheetDestination: Identifiable {
        /// Create recipe wizard.
        case createRecipe
        /// CookSavvy+ upgrade prompt.
        case upgrade
        /// Shopping list management.
        case shoppingList

        var id: String {
            switch self {
            case .createRecipe: return "createRecipe"
            case .upgrade: return "upgrade"
            case .shoppingList: return "shoppingList"
            }
        }
    }

    /// Full-screen cover destinations for the My Kitchen tab.
    enum FullScreenCoverDestination: Identifiable {
        /// Step-by-step cook mode for the given recipe.
        case cookMode(Recipe)

        var id: String {
            switch self {
            case .cookMode(let recipe): return "cookMode_\(recipe.id)"
            }
        }
    }
}

// MARK: - Coordinator View

/// Internal SwiftUI coordinator view that hosts the Journey navigation stack and applies
/// full-screen cover and sheet presentations driven by `JourneyCoordinator`.
///
/// Reloads Journey data via `JourneyViewModel.loadData()` whenever a sheet or cover is dismissed.
struct JourneyCoordinatorView: View {
    @ObservedObject var coordinator: JourneyCoordinator
    @StateObject private var journeyViewModel: JourneyViewModel

    /// Creates the coordinator view and pins the root `JourneyViewModel` as a state object.
    init(coordinator: JourneyCoordinator) {
        self.coordinator = coordinator
        _journeyViewModel = StateObject(wrappedValue: coordinator.makeJourneyViewModel())
    }

    var body: some View {
        navigationContent
        .fullScreenCover(
            item: $coordinator.presentedFullScreenCover,
            onDismiss: reloadJourneyData,
            content: fullScreenDestinationView
        )
        .sheet(
            item: $coordinator.presentedSheet,
            onDismiss: reloadJourneyData,
            content: sheetDestinationView
        )
    }

    private var navigationContent: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            JourneyView(viewModel: journeyViewModel)
                .navigationDestination(
                    for: JourneyCoordinator.NavigationDestination.self,
                    destination: navigationDestinationView
                )
        }
    }

    @ViewBuilder
    /// Maps pushed Journey destinations to concrete destination views.
    private func navigationDestinationView(_ destination: JourneyCoordinator.NavigationDestination) -> some View {
        switch destination {
        case .recipeDetail(let recipe):
            RecipeDetailsView(
                viewModel: coordinator.makeRecipeDetailsViewModel(
                    recipe: recipe,
                    selectedIngredients: coordinator.selectedIngredients(for: recipe)
                )
            )
        case .recipeList(let title, let recipes):
            RecipeListView(
                viewModel: coordinator.makeRecipeListViewModel(title: title, recipes: recipes)
            )
        case .settings:
            JourneySettingsDestination(settingsCoordinator: coordinator.settingsCoordinator)
        }
    }

    @ViewBuilder
    /// Maps Journey full-screen destinations to their presentation views.
    private func fullScreenDestinationView(_ destination: JourneyCoordinator.FullScreenCoverDestination) -> some View {
        switch destination {
        case .cookMode(let recipe):
            CookModeView(
                viewModel: coordinator.makeCookModeViewModel(recipe: recipe)
            )
        }
    }

    @ViewBuilder
    /// Maps Journey sheet destinations to their presentation views.
    private func sheetDestinationView(_ sheet: JourneyCoordinator.SheetDestination) -> some View {
        switch sheet {
        case .upgrade:
            UpgradeView(viewModel: coordinator.makeUpgradeViewModel())
        case .createRecipe:
            CreateRecipeView(viewModel: coordinator.makeCreateRecipeViewModel())
        case .shoppingList:
            ShoppingListView(viewModel: coordinator.makeShoppingListViewModel())
        }
    }

    /// Reloads Journey screen data after modal presentations are dismissed.
    private func reloadJourneyData() {
        Task {
            await journeyViewModel.loadData()
        }
    }
}

/// Local coordinator-only helpers that should not surface on the public API.
private extension JourneyCoordinator {
    /// Retrieves the cached selected ingredients for a given recipe, or an empty array if none were stored.
    func selectedIngredients(for recipe: Recipe) -> [Ingredient] {
        recipeDetailSelectedIngredients[recipe.id] ?? []
    }
}

// MARK: - Settings Destination Wrapper

/// A navigation destination wrapper that embeds the Settings screen within the Journey navigation stack.
///
/// Owns its own `SettingsViewModel` via `@StateObject` while observing the shared
/// `SettingsCoordinator` for sheet presentations (e.g., the upgrade sheet).
struct JourneySettingsDestination: View {
    @ObservedObject var settingsCoordinator: SettingsCoordinator
    @StateObject private var viewModel: SettingsViewModel
    
    /// Creates a settings destination wrapper that owns a persistent settings view model.
    init(settingsCoordinator: SettingsCoordinator) {
        self.settingsCoordinator = settingsCoordinator
        _viewModel = StateObject(wrappedValue: settingsCoordinator.makeSettingsViewModel())
    }
    
    var body: some View {
        SettingsView(viewModel: viewModel)
            .sheet(
                item: $settingsCoordinator.presentedSheet,
                content: settingsSheetView
            )
    }

    @ViewBuilder
    /// Maps settings sheet destinations presented from inside the Journey stack.
    private func settingsSheetView(_ sheet: SettingsCoordinator.SheetDestination) -> some View {
        switch sheet {
        case .upgrade:
            UpgradeView(viewModel: settingsCoordinator.makeUpgradeViewModel())
        }
    }
}
