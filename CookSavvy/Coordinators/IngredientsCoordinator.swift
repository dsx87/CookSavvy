//
//  IngredientsCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class IngredientsCoordinator: ObservableObject {
    
    private let container: AppContainer
    @Published var navigationPath = NavigationPath()
    
    init(container: AppContainer) {
        self.container = container
    }
    
    func start() -> some View {
        IngredientsCoordinatorView(coordinator: self)
    }
    
    func makeIngredientsInputViewModel() -> IngredientsInputViewModel {
        IngredientsInputViewModel(
            ingredientsService: container.ingredientsService,
            userDataService: container.userDataService,
            databaseInitService: container.databaseInitService,
            coordinator: self
        )
    }
    
    func makeRecipesResultViewModel(selectedIngredients: Set<Ingredient>) -> RecipesResultViewModel {
        RecipesResultViewModel(
            selectedIngredients: selectedIngredients,
            recipeService: container.recipeService,
            imageService: container.imageService,
            databaseInitService: container.databaseInitService,
            userDataService: container.userDataService,
            coordinator: self
        )
    }
    
    func makeRecipeDetailsViewModel(recipe: Recipe) -> RecipeDetailsViewModel {
        RecipeDetailsViewModel(
            recipe: recipe,
            userDataService: container.userDataService
        )
    }
    
    func showRecipesResult() {
        navigationPath.append(NavigationDestination.recipesResult)
    }
    
    func showRecipeDetails(recipe: Recipe) {
        navigationPath.append(NavigationDestination.recipeDetails(recipe))
    }
    
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}

extension IngredientsCoordinator {
    enum NavigationDestination: Hashable {
        case recipesResult
        case recipeDetails(Recipe)
    }
}

struct IngredientsCoordinatorView: View {
    @ObservedObject var coordinator: IngredientsCoordinator
    @StateObject private var viewModel: IngredientsInputViewModel
    
    init(coordinator: IngredientsCoordinator) {
        self.coordinator = coordinator
        _viewModel = StateObject(wrappedValue: coordinator.makeIngredientsInputViewModel())
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            IngredientsInputView(viewModel: viewModel)
                .navigationDestination(for: IngredientsCoordinator.NavigationDestination.self) { destination in
                    switch destination {
                    case .recipesResult:
                        RecipesResultView(
                            viewModel: coordinator.makeRecipesResultViewModel(
                                selectedIngredients: viewModel.selectedIngredients
                            )
                        )
                    case .recipeDetails(let recipe):
                        RecipeDetailsView(
                            viewModel: coordinator.makeRecipeDetailsViewModel(recipe: recipe)
                        )
                    }
                }
        }
    }
}
