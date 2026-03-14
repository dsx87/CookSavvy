//
//  RecipeDetailsViewModel.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI

@MainActor
protocol RecipeDetailsCoordinating: AnyObject {
    func showCookMode(recipe: Recipe)
}

@MainActor
final class RecipeDetailsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recipe: Recipe
    @Published var isFavorite: Bool = false
    @Published var isLoadingFavorite: Bool = false

    // MARK: - Properties

    let selectedIngredients: [Ingredient]
    private let userDataService: UserDataService
    private weak var coordinator: (any RecipeDetailsCoordinating)?

    // MARK: - Initialization

    init(
        recipe: Recipe,
        selectedIngredients: [Ingredient] = [],
        userDataService: UserDataService,
        coordinator: (any RecipeDetailsCoordinating)?
    ) {
        self.recipe = recipe
        self.selectedIngredients = selectedIngredients
        self.userDataService = userDataService
        self.coordinator = coordinator

        // Load data on init
        Task {
            await loadData()
        }
    }

    // MARK: - Public Methods

    func loadData() async {
        await loadFavoriteStatus()
        await recordView()
    }

    func toggleFavorite() async {
        isLoadingFavorite = true
        defer { isLoadingFavorite = false }

        do {
            isFavorite = try await userDataService.toggleFavorite(recipe)
        } catch {
            print("❌ Failed to toggle favorite: \(error)")
        }
    }

    func startCooking() {
        coordinator?.showCookMode(recipe: recipe)
    }

    enum IngredientStatus {
        case available, missing, unknown
    }

    func ingredientStatus(_ ingredient: Ingredient) -> IngredientStatus {
        guard !selectedIngredients.isEmpty else { return .unknown }
        let queryNames = Set(selectedIngredients.map { RecipeMatchExplainer.normalizedIngredientName($0.name) }.filter { !$0.isEmpty })
        let recipeName = RecipeMatchExplainer.normalizedIngredientName(ingredient.name)
        let isMatch = queryNames.contains(where: { recipeName.contains($0) || $0.contains(recipeName) })
        return isMatch ? .available : .missing
    }

    // MARK: - Private Methods

    private func loadFavoriteStatus() async {
        do {
            isFavorite = try await userDataService.isFavorite(recipe)
        } catch {
            print("❌ Failed to load favorite status: \(error)")
            isFavorite = false
        }
    }

    private func recordView() async {
        do {
            try await userDataService.recordRecipeView(recipe)
        } catch {
            print("❌ Failed to record recipe view: \(error)")
        }
    }
}
