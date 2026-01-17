//
//  FavoritesCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class FavoritesCoordinator: ObservableObject {
    
    private let container: AppContainer
    @Published var navigationPath = NavigationPath()
    
    init(container: AppContainer) {
        self.container = container
    }
    
    func start() -> some View {
        FavoritesCoordinatorView(coordinator: self)
    }
    
    func makeFavoritesViewModel() -> FavoritesViewModel {
        FavoritesViewModel(
            userDataService: container.userDataService,
            imageService: container.imageService,
            coordinator: self
        )
    }
    
    func makeRecipeDetailsViewModel(recipe: Recipe) -> RecipeDetailsViewModel {
        RecipeDetailsViewModel(
            recipe: recipe,
            userDataService: container.userDataService
        )
    }
    
    func showRecipeDetails(recipe: Recipe) {
        navigationPath.append(recipe)
    }
    
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}

struct FavoritesCoordinatorView: View {
    @ObservedObject var coordinator: FavoritesCoordinator
    @StateObject private var viewModel: FavoritesViewModel
    
    init(coordinator: FavoritesCoordinator) {
        self.coordinator = coordinator
        _viewModel = StateObject(wrappedValue: coordinator.makeFavoritesViewModel())
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            FavoritesView(viewModel: viewModel)
                .navigationDestination(for: Recipe.self) { recipe in
                    RecipeDetailsView(
                        viewModel: coordinator.makeRecipeDetailsViewModel(recipe: recipe)
                    )
                }
        }
    }
}
