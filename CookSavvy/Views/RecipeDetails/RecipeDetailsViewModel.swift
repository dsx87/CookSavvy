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
    func showShoppingList()
    func showUpgrade()
}

@MainActor
final class RecipeDetailsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recipe: Recipe
    @Published var isFavorite: Bool = false
    @Published var isLoadingFavorite: Bool = false

    // MARK: - Properties

    let selectedIngredients: [Ingredient]
    private let userDataService: UserDataServiceProtocol
    private let shoppingListService: ShoppingListServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private weak var coordinator: (any RecipeDetailsCoordinating)?

    // MARK: - Computed

    var missingIngredientNames: [String] {
        if !selectedIngredients.isEmpty {
            return recipe.ingredients.filter { ingredientStatus($0) == .missing }.map { $0.name }
        }
        // Fall back to pre-computed missing ingredients from search (e.g. "See All" path)
        return recipe.missingIngredients ?? []
    }

    var canShowAddToShoppingList: Bool { !missingIngredientNames.isEmpty }

    // MARK: - Initialization

    init(
        recipe: Recipe,
        selectedIngredients: [Ingredient] = [],
        userDataService: UserDataServiceProtocol,
        shoppingListService: ShoppingListServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        coordinator: (any RecipeDetailsCoordinating)?
    ) {
        self.recipe = recipe
        self.selectedIngredients = selectedIngredients
        self.userDataService = userDataService
        self.shoppingListService = shoppingListService
        self.subscriptionService = subscriptionService
        self.analyticsService = analyticsService
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
            if isFavorite {
                analyticsService.track(.recipeFavorited)
            }
        } catch {
            print("❌ Failed to toggle favorite: \(error)")
        }
    }

    func startCooking() {
        coordinator?.showCookMode(recipe: recipe)
    }

    func addMissingToShoppingList() async {
        let missing = missingIngredientNames
        guard !missing.isEmpty else { return }
        guard subscriptionService.canAccessFeature(.shoppingList) else {
            coordinator?.showUpgrade()
            return
        }
        do {
            _ = try await shoppingListService.addItems(missing, recipeTitle: recipe.title)
            coordinator?.showShoppingList()
        } catch {
            print("❌ Failed to add items to shopping list: \(error)")
        }
    }

    func showShoppingList() {
        guard subscriptionService.canAccessFeature(.shoppingList) else {
            coordinator?.showUpgrade()
            return
        }
        coordinator?.showShoppingList()
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
        analyticsService.track(.recipeViewed)
        do {
            try await userDataService.recordRecipeView(recipe)
        } catch {
            print("❌ Failed to record recipe view: \(error)")
        }
    }
}
