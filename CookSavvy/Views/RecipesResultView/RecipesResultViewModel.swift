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
    private let subscriptionService: SubscriptionServiceProtocol
    private weak var coordinator: IngredientsCoordinator?

    deinit {
        // TODO: Fix the deinit of the view model
        print("FUUUCKKK")
    }
    
    init(
        selectedIngredients: Set<Ingredient>,
        recipeService: RecipeService,
        imageService: ImageService,
        databaseInitService: DatabaseInitializationService,
        userDataService: UserDataService,
        subscriptionService: SubscriptionServiceProtocol,
        coordinator: IngredientsCoordinator?
    ) {
        self.selectedIngredients = selectedIngredients
        self.recipeService = recipeService
        self.imageService = imageService
        self.databaseInitService = databaseInitService
        self.userDataService = userDataService
        self.subscriptionService = subscriptionService
        self.coordinator = coordinator
    }

    func loadRecipes() async {
        guard !selectedIngredients.isEmpty else {
            recipes = []
            images = [:]
            return
        }
        
        guard recipes.isEmpty else {
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
            let enabledSources = getAccessibleEnabledSources()
            
            recipes = try await recipeService.getRecipes(for: lowercaseIngredients, from: enabledSources)
        } catch {
            print("❌ Error loading recipes: \(error)")
            errorMessage = "Failed to load recipes: \(error.localizedDescription)"
            recipes = []
            images = [:]
        }
    }
    
    func handleRecipeSelection(_ recipe: Recipe) {
        coordinator?.showRecipeDetails(recipe: recipe)
    }

    func handleBack() {
        coordinator?.goBack()
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
    
    private func getAccessibleEnabledSources() -> Set<RecipeSourceType> {
        var sources = userDataService.getEnabledSources()
        
        if sources.contains(.ai) && !subscriptionService.canAccessFeature(.aiRecipes) {
            sources.remove(.ai)
        }
        if sources.contains(.online) && !subscriptionService.canAccessFeature(.onlineRecipes) {
            sources.remove(.online)
        }
        
        return sources.isEmpty ? [.offline] : sources
    }
}
