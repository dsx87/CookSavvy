//
//  RecipesResultViewModel.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 03/07/2025.
//

import SwiftUI

@MainActor
final class RecipesResultViewModel: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var images: [String: UIImage] = [:]
    @Published var isLoading: Bool = false
    @Published var isWaitingForDatabase: Bool = false
    @Published var errorMessage: String?

    private(set) var selectedIngredients: Set<Ingredient>

    private let recipeService: RecipeService
    private let imageService: ImageService
    private let databaseInitService: DatabaseInitializationService
    private let userDataService: UserDataService
    private let navigationPath: Binding<NavigationPath>

    var userDataServiceForNavigation: UserDataService {
        userDataService
    }

    init(
        selectedIngredients: Set<Ingredient>,
        navigationPath: Binding<NavigationPath>,
        recipeService: RecipeService,
        imageService: ImageService,
        databaseInitService: DatabaseInitializationService,
        userDataService: UserDataService
    ) {
        self.selectedIngredients = selectedIngredients
        self.navigationPath = navigationPath
        self.recipeService = recipeService
        self.imageService = imageService
        self.databaseInitService = databaseInitService
        self.userDataService = userDataService
    }

    func loadRecipes() async {
        guard !selectedIngredients.isEmpty else {
            recipes = []
            images = [:]
            return
        }

        if !databaseInitService.state.isRecipesReady {
            isWaitingForDatabase = true
            await databaseInitService.waitForRecipes()
            isWaitingForDatabase = false
            
            if case .failed(let message) = databaseInitService.state {
                errorMessage = "Database initialization failed: \(message)"
                return
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            defer { isLoading = false }

            let lowercaseIngredients = normalizedIngredients()

            recipes = try await recipeService.getRecipes(for: lowercaseIngredients)
            images = [:]//try await imageService.loadImages(for: recipes)
        } catch {
            print("❌ Error loading recipes: \(error)")
            errorMessage = "Failed to load recipes: \(error.localizedDescription)"
            recipes = []
            images = [:]
        }
    }

    func getImage(for recipe: Recipe) -> UIImage? {
        images[recipe.id]
    }

    func handleRecipeSelection(_ recipe: Recipe) {
        navigationPath.wrappedValue.append(recipe)
    }

    func handleBack() {
        guard !navigationPath.wrappedValue.isEmpty else { return }
        navigationPath.wrappedValue.removeLast()
    }

    private func normalizedIngredients() -> [Ingredient] {
        selectedIngredients.map { ingredient in
            Ingredient(
                name: ingredient.name.lowercased(),
                description: ingredient.description,
                pictureFileName: ingredient.pictureFileName,
                foodGroup: ingredient.foodGroup,
                foodSubgroup: ingredient.foodSubgroup
            )
        }
    }
}
