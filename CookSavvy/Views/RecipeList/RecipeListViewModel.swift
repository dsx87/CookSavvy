import SwiftUI

@MainActor
final class RecipeListViewModel: ObservableObject {
    let title: String
    @Published var recipes: [Recipe]
    @Published private var savedIds: Set<String> = []

    private let userDataService: UserDataService

    init(title: String, recipes: [Recipe], userDataService: UserDataService) {
        self.title = title
        self.recipes = recipes
        self.userDataService = userDataService
    }

    func loadSavedStatus() async {
        do {
            let savedRecipes = try await userDataService.getSavedRecipes()
            savedIds = Set(savedRecipes.map(\.id))
        } catch {}
    }

    func isSaved(_ recipe: Recipe) -> Bool {
        recipe.isUserCreated || savedIds.contains(recipe.id)
    }
}
