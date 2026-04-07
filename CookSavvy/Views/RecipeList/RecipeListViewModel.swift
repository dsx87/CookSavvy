import SwiftUI

@MainActor
protocol RecipeListCoordinating: AnyObject {
    func showRecipeFromList(_ recipe: Recipe)
}

@MainActor
final class RecipeListViewModel: ObservableObject {
    let title: String
    @Published var recipes: [Recipe]
    @Published private var savedIds: Set<String> = []

    private let userDataService: UserDataServiceProtocol
    private let logger: any LoggerProtocol
    private weak var coordinator: (any RecipeListCoordinating)?

    init(
        title: String,
        recipes: [Recipe],
        userDataService: UserDataServiceProtocol,
        logger: any LoggerProtocol,
        coordinator: (any RecipeListCoordinating)? = nil
    ) {
        self.title = title
        self.recipes = recipes
        self.userDataService = userDataService
        self.logger = logger
        self.coordinator = coordinator
    }

    func loadSavedStatus() async {
        do {
            let savedRecipes = try await userDataService.getSavedRecipes()
            savedIds = Set(savedRecipes.map(\.id))
        } catch {
            logger.error("Failed to load saved recipe status: \(String(describing: error))")
        }
    }

    func isSaved(_ recipe: Recipe) -> Bool {
        recipe.isUserCreated || savedIds.contains(recipe.id)
    }

    func showRecipeDetails(_ recipe: Recipe) {
        coordinator?.showRecipeFromList(recipe)
    }
}
