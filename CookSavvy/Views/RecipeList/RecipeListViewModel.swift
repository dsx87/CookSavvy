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
            let favorites = try await userDataService.getFavorites()
            savedIds = Set(favorites.map(\.id))
        } catch {}
    }

    func isSaved(_ recipe: Recipe) -> Bool {
        savedIds.contains(recipe.id)
    }
}
