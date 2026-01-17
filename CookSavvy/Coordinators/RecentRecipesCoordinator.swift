//
//  RecentRecipesCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class RecentRecipesCoordinator: ObservableObject {
    
    private let container: AppContainer
    @Published var navigationPath = NavigationPath()
    
    init(container: AppContainer) {
        self.container = container
    }
    
    func start() -> some View {
        RecentRecipesCoordinatorView(coordinator: self)
    }
    
    func makeRecentRecipesViewModel() -> RecentRecipesViewModel {
        RecentRecipesViewModel(
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

struct RecentRecipesCoordinatorView: View {
    @ObservedObject var coordinator: RecentRecipesCoordinator
    @StateObject private var viewModel: RecentRecipesViewModel
    
    init(coordinator: RecentRecipesCoordinator) {
        self.coordinator = coordinator
        _viewModel = StateObject(wrappedValue: coordinator.makeRecentRecipesViewModel())
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            RecentRecipesView(viewModel: viewModel)
                .navigationDestination(for: Recipe.self) { recipe in
                    RecipeDetailsView(
                        viewModel: coordinator.makeRecipeDetailsViewModel(recipe: recipe)
                    )
                }
        }
    }
}
