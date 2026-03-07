//
//  DiscoverCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class DiscoverCoordinator: ObservableObject, RecipeDetailsCoordinating {
    
    private let container: AppContainer
    @Published var navigationPath = NavigationPath()
    @Published var presentedSheet: SheetDestination?
    @Published var presentedFullScreenCover: FullScreenCoverDestination?
    
    init(container: AppContainer) {
        self.container = container
    }
    
    func start() -> some View {
        DiscoverCoordinatorView(coordinator: self)
    }
    
    // MARK: - Factory Methods
    
    func makeRecipeDetailsViewModel(recipe: Recipe) -> RecipeDetailsViewModel {
        RecipeDetailsViewModel(
            recipe: recipe,
            userDataService: container.userDataService,
            coordinator: self
        )
    }
    
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
    
    func makeUpgradeViewModel() -> UpgradeViewModel {
        UpgradeViewModel(
            subscriptionService: container.subscriptionService,
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

    func makeDiscoverViewModel() -> DiscoverViewModel {
        DiscoverViewModel(
            ingredientsService: container.ingredientsService,
            recipeService: container.recipeService,
            userDataService: container.userDataService,
            subscriptionService: container.subscriptionService,
            databaseInitService: container.databaseInitService,
            coordinator: self
        )
    }

    func makeRecipeListViewModel(title: String, recipes: [Recipe]) -> RecipeListViewModel {
        RecipeListViewModel(
            title: title,
            recipes: recipes,
            userDataService: container.userDataService
        )
    }

    func makeCookModeViewModel(recipe: Recipe) -> CookModeViewModel {
        CookModeViewModel(
            recipe: recipe,
            userDataService: container.userDataService,
            onDismiss: { [weak self] in
                self?.dismissFullScreenCover()
            }
        )
    }
    
    // MARK: - Navigation
    
    func showRecipeDetails(recipe: Recipe) {
        navigationPath.append(NavigationDestination.recipeDetail(recipe))
    }
    
    func showRecipeList(title: String, recipes: [Recipe]) {
        navigationPath.append(NavigationDestination.recipeList(title: title, recipes: recipes))
    }
    
    func showCookMode(recipe: Recipe) {
        presentedFullScreenCover = .cookMode(recipe)
    }
    
    func showCamera() {
        presentedFullScreenCover = .camera
    }
    
    func showUpgrade() {
        presentedSheet = .upgrade
    }
    
    func showCreateRecipe() {
        presentedSheet = .createRecipe
    }
    
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func dismissSheet() {
        presentedSheet = nil
        presentedFullScreenCover = nil
    }
    
    func dismissFullScreenCover() {
        presentedFullScreenCover = nil
    }
}

// MARK: - Destinations

extension DiscoverCoordinator {
    enum NavigationDestination: Hashable {
        case recipeDetail(Recipe)
        case recipeList(title: String, recipes: [Recipe])
    }
    
    enum SheetDestination: Identifiable {
        case upgrade
        case createRecipe
        
        var id: String {
            switch self {
            case .upgrade: return "upgrade"
            case .createRecipe: return "createRecipe"
            }
        }
    }
    
    enum FullScreenCoverDestination: Identifiable {
        case camera
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

struct DiscoverCoordinatorView: View {
    @ObservedObject var coordinator: DiscoverCoordinator
    @StateObject private var discoverViewModel: DiscoverViewModel
    
    init(coordinator: DiscoverCoordinator) {
        self.coordinator = coordinator
        _discoverViewModel = StateObject(wrappedValue: coordinator.makeDiscoverViewModel())
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            DiscoverView(viewModel: discoverViewModel)
                .navigationDestination(for: DiscoverCoordinator.NavigationDestination.self) { destination in
                    switch destination {
                    case .recipeDetail(let recipe):
                        RecipeDetailsView(
                            viewModel: coordinator.makeRecipeDetailsViewModel(recipe: recipe)
                        )
                    case .recipeList(let title, let recipes):
                        RecipeListView(
                            viewModel: coordinator.makeRecipeListViewModel(title: title, recipes: recipes),
                            onRecipeTap: { recipe in
                                coordinator.showRecipeDetails(recipe: recipe)
                            }
                        )
                    }
                }
        }
        .fullScreenCover(item: $coordinator.presentedFullScreenCover) { destination in
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
            }
        }
    }
}
