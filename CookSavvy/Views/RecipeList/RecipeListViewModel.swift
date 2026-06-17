import SwiftUI

/// Coordinator interface consumed by ``RecipeListViewModel`` for detail navigation.
protocol RecipeListCoordinating: AnyObject {
    /// Opens recipe details from a list row selection.
    func showRecipeFromList(_ recipe: Recipe)
}

/// ViewModel backing the Recipe List "See All" screen.
///
/// Displays a flat list of recipes passed in from the parent screen (saved, recent, or user-created).
/// Lazily loads the saved/favourite status for each recipe so bookmark icons render correctly.
@Observable final class RecipeListViewModel {
    /// The navigation title for this list (e.g. "Saved Recipes" or "My Recipes").
    let title: String
    /// The recipes to display.
    var recipes: [Recipe]
    /// IDs of recipes the user has saved/favourited; populated by `loadSavedStatus()`.
    private var savedIds: Set<String> = []

    private let userDataService: UserDataServiceProtocol
    private let logger: any LoggerProtocol
    private weak var coordinator: (any RecipeListCoordinating)?

    /// Creates a recipe-list view model with list metadata and dependencies.
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

    /// Fetches saved recipes from `UserDataService` and builds the `savedIds` set.
    func loadSavedStatus() async {
        do {
            let savedRecipes = try await userDataService.getSavedRecipes()
            savedIds = Set(savedRecipes.map(\.id))
        } catch {
            logger.error("Failed to load saved recipe status: \(String(describing: error))")
        }
    }

    /// Returns `true` if the recipe is saved or user-created (always considered "saved").
    func isSaved(_ recipe: Recipe) -> Bool {
        recipe.isUserCreated || savedIds.contains(recipe.id)
    }

    /// Navigates to the recipe detail screen for the given recipe.
    func showRecipeDetails(_ recipe: Recipe) {
        coordinator?.showRecipeFromList(recipe)
    }
}
