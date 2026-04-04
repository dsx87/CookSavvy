//
//  JourneyCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class JourneyCoordinator: ObservableObject, JourneyCoordinating, RecipeListCoordinating {
    
    private let container: AppContainer
    let settingsCoordinator: SettingsCoordinator
    @Published var navigationPath = NavigationPath()
    @Published var presentedSheet: SheetDestination?
    @Published var presentedFullScreenCover: FullScreenCoverDestination?
    
    init(container: AppContainer, settingsCoordinator: SettingsCoordinator) {
        self.container = container
        self.settingsCoordinator = settingsCoordinator
    }
    
    func start() -> some View {
        JourneyCoordinatorView(coordinator: self)
    }
    
    // MARK: - Factory Methods
    
    func makeRecipeDetailsViewModel(recipe: Recipe) -> RecipeDetailsViewModel {
        RecipeDetailsViewModel(
            recipe: recipe,
            userDataService: container.userDataService,
            shoppingListService: container.shoppingListService,
            subscriptionService: container.subscriptionService,
            analyticsService: container.analyticsService,
            coordinator: self
        )
    }

    func makeShoppingListViewModel() -> ShoppingListViewModel {
        ShoppingListViewModel(
            shoppingListService: container.shoppingListService,
            onDismiss: { [weak self] in self?.dismissSheet() }
        )
    }
    
    func makeUpgradeViewModel() -> UpgradeViewModel {
        UpgradeViewModel(
            subscriptionService: container.subscriptionService,
            analyticsService: container.analyticsService,
            onDismiss: { [weak self] in
                self?.dismissSheet()
            }
        )
    }
    
    func makeCreateRecipeViewModel() -> CreateRecipeViewModel {
        CreateRecipeViewModel(
            userDataService: container.userDataService,
            onDismiss: { [weak self] in
                self?.dismissSheet()
            }
        )
    }

    func makeJourneyViewModel() -> JourneyViewModel {
        JourneyViewModel(
            userDataService: container.userDataService,
            subscriptionService: container.subscriptionService,
            cameraScanTracker: container.cameraScanTracker,
            analyticsService: container.analyticsService,
            coordinator: self
        )
    }

    func makeRecipeListViewModel(title: String, recipes: [Recipe]) -> RecipeListViewModel {
        RecipeListViewModel(
            title: title,
            recipes: recipes,
            userDataService: container.userDataService,
            coordinator: self
        )
    }

    func makeCookModeViewModel(recipe: Recipe) -> CookModeViewModel {
        CookModeViewModel(
            recipe: recipe,
            userDataService: container.userDataService,
            analyticsService: container.analyticsService,
            onDismiss: { [weak self] in
                self?.dismissFullScreenCover()
            }
        )
    }
    
    // MARK: - Navigation
    
    func showRecipeDetail(recipe: Recipe) {
        navigationPath.append(NavigationDestination.recipeDetail(recipe))
    }
    
    func showRecipeList(title: String, recipes: [Recipe]) {
        navigationPath.append(NavigationDestination.recipeList(title: title, recipes: recipes))
    }

    func showRecipeFromList(_ recipe: Recipe) {
        showRecipeDetail(recipe: recipe)
    }
    
    func showSettings() {
        navigationPath.append(NavigationDestination.settings)
    }
    
    func showCreateRecipe() {
        presentedSheet = .createRecipe
    }
    
    func showCookMode(recipe: Recipe) {
        presentedFullScreenCover = .cookMode(recipe)
    }
    
    func showUpgrade() {
        presentedSheet = .upgrade
    }

    func showShoppingList() {
        presentedSheet = .shoppingList
    }
    
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }

    func dismissFullScreenCover() {
        presentedFullScreenCover = nil
    }
}

// MARK: - Destinations

extension JourneyCoordinator {
    enum NavigationDestination: Hashable {
        case recipeDetail(Recipe)
        case recipeList(title: String, recipes: [Recipe])
        case settings
    }
    
    enum SheetDestination: Identifiable {
        case createRecipe
        case upgrade
        case shoppingList

        var id: String {
            switch self {
            case .createRecipe: return "createRecipe"
            case .upgrade: return "upgrade"
            case .shoppingList: return "shoppingList"
            }
        }
    }

    enum FullScreenCoverDestination: Identifiable {
        case cookMode(Recipe)

        var id: String {
            switch self {
            case .cookMode(let recipe): return "cookMode_\(recipe.id)"
            }
        }
    }
}

// MARK: - Coordinator View

struct JourneyCoordinatorView: View {
    @ObservedObject var coordinator: JourneyCoordinator
    @StateObject private var journeyViewModel: JourneyViewModel

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
    private func navigationDestinationView(_ destination: JourneyCoordinator.NavigationDestination) -> some View {
        switch destination {
        case .recipeDetail(let recipe):
            RecipeDetailsView(
                viewModel: coordinator.makeRecipeDetailsViewModel(recipe: recipe)
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
    private func fullScreenDestinationView(_ destination: JourneyCoordinator.FullScreenCoverDestination) -> some View {
        switch destination {
        case .cookMode(let recipe):
            CookModeView(
                viewModel: coordinator.makeCookModeViewModel(recipe: recipe)
            )
        }
    }

    @ViewBuilder
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

    private func reloadJourneyData() {
        Task {
            await journeyViewModel.loadData()
        }
    }
}

// MARK: - Settings Destination Wrapper

struct JourneySettingsDestination: View {
    @ObservedObject var settingsCoordinator: SettingsCoordinator
    @StateObject private var viewModel: SettingsViewModel
    
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
    private func settingsSheetView(_ sheet: SettingsCoordinator.SheetDestination) -> some View {
        switch sheet {
        case .upgrade:
            UpgradeView(viewModel: settingsCoordinator.makeUpgradeViewModel())
        }
    }
}
