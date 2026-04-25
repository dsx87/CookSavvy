//
//  RecipeDetailsViewModel.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI

@MainActor
/// Coordinator interface consumed by ``RecipeDetailsViewModel`` for navigation.
protocol RecipeDetailsCoordinating: AnyObject {
    /// Opens cook mode for a specific recipe.
    func showCookMode(recipe: Recipe)
    /// Opens the shopping list sheet.
    func showShoppingList()
    /// Opens the upgrade/paywall flow.
    func showUpgrade()
}

/// ViewModel backing the Recipe Details screen.
///
/// Owns:
/// - The displayed recipe and the ingredient selection context passed in from the search
/// - Favourite/bookmark toggle state (persisted via `UserDataService`)
/// - "Add Missing to Shopping List" logic, gated behind the shopping-list `PaidFeature`
/// - Ingredient status computation (available vs. missing vs. unknown)
/// - Automatic view recording on load for recents and analytics
///
/// Delegates navigation (Cook Mode, Shopping List, Upgrade) to a `RecipeDetailsCoordinating` coordinator.
@MainActor
final class RecipeDetailsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The recipe being displayed; may be mutated if recipe data is refreshed.
    @Published var recipe: Recipe {
        didSet { rebuildIngredientMatchCache() }
    }
    /// `true` when this recipe is in the user's favourites list.
    @Published var isFavorite: Bool = false
    /// `true` while a favourite-toggle request is in flight.
    @Published var isLoadingFavorite: Bool = false
    /// Non-`nil` when any action fails; drives the error alert.
    @Published var errorMessage: String?
    /// Generated PNG image used as the primary system share-sheet item.
    @Published private(set) var shareCard: RecipeShareCard?
    /// `true` until the visual share card has rendered.
    @Published private(set) var isPreparingShareCard: Bool = true

    // MARK: - Properties

    /// The ingredients selected by the user when this recipe was found; used for match highlighting.
    let selectedIngredients: [Ingredient]
    private let userDataService: UserDataServiceProtocol
    private let shoppingListService: ShoppingListServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let shareCardGenerator: RecipeShareCardGenerating
    private let analyticsService: AnalyticsServiceProtocol
    private let logger: any LoggerProtocol
    private weak var coordinator: (any RecipeDetailsCoordinating)?
    /// Cached pantry-plus match split and ingredient-row statuses for the current recipe.
    private var ingredientMatchCache: IngredientMatchCache?

    // MARK: - Computed

    /// Ingredient names that should be bought for this recipe.
    ///
    /// When a selection is present, recomputes live using the same pantry-plus breakdown as Discover
    /// so assumed staples are not added to the shopping list.
    /// Falls back to the pre-computed `recipe.missingIngredients` set (populated during search) when
    /// the detail screen is opened without an ingredient context (e.g. from "See All").
    var missingIngredientNames: [String] {
        if !selectedIngredients.isEmpty {
            return currentIngredientMatchCache()?.breakdown.missingIngredientNames ?? []
        }
        // Fall back to pre-computed missing ingredients from search (e.g. "See All" path)
        return recipe.missingIngredients ?? []
    }

    /// `true` when there are missing ingredients that can be added to the shopping list.
    var canShowAddToShoppingList: Bool { !missingIngredientNames.isEmpty }

    // MARK: - Initialization

    /// Creates a recipe-details view model with injected services and optional coordinator.
    init(
        recipe: Recipe,
        selectedIngredients: [Ingredient] = [],
        userDataService: UserDataServiceProtocol,
        shoppingListService: ShoppingListServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        shareCardGenerator: RecipeShareCardGenerating,
        analyticsService: AnalyticsServiceProtocol,
        logger: any LoggerProtocol,
        coordinator: (any RecipeDetailsCoordinating)?
    ) {
        self.recipe = recipe
        self.selectedIngredients = selectedIngredients
        self.userDataService = userDataService
        self.shoppingListService = shoppingListService
        self.subscriptionService = subscriptionService
        self.shareCardGenerator = shareCardGenerator
        self.analyticsService = analyticsService
        self.logger = logger
        self.coordinator = coordinator
        rebuildIngredientMatchCache()

        // Load data on init
        Task {
            await loadData()
        }
        Task {
            await prepareShareCard()
        }
    }

    // MARK: - Public Methods

    /// Loads initial data: favourite status check and view-recording (analytics + recents).
    func loadData() async {
        await loadFavoriteStatus()
        await recordView()
    }

    /// Pre-renders the share-sheet image so tapping Share presents a ready PNG item.
    func prepareShareCard() async {
        isPreparingShareCard = true
        shareCard = await shareCardGenerator.makeShareCard(for: recipe)
        isPreparingShareCard = false
    }

    /// Persists or removes this recipe from the user's favourites, toggling `isFavorite`.
    func toggleFavorite() async {
        isLoadingFavorite = true
        errorMessage = nil
        defer { isLoadingFavorite = false }

        do {
            isFavorite = try await userDataService.toggleFavorite(recipe)
            if isFavorite {
                analyticsService.track(.recipeFavorited)
            }
        } catch {
            logger.error("Failed to toggle recipe favorite: \(String(describing: error))")
            errorMessage = Strings.Errors.favoriteFailed
        }
    }

    /// Navigates to Cook Mode for step-by-step cooking of this recipe.
    func startCooking() {
        coordinator?.showCookMode(recipe: recipe)
    }

    /// Adds all missing ingredients to the shopping list and navigates to it.
    ///
    /// Redirects to the Upgrade paywall if the user does not have shopping list access.
    func addMissingToShoppingList() async {
        let missing = missingIngredientNames
        guard !missing.isEmpty else { return }
        errorMessage = nil
        guard subscriptionService.canAccessFeature(.shoppingList) else {
            coordinator?.showUpgrade()
            return
        }
        do {
            _ = try await shoppingListService.addItems(missing, recipeTitle: recipe.title)
            coordinator?.showShoppingList()
        } catch {
            logger.error("Failed to add items to shopping list: \(String(describing: error))")
            errorMessage = Strings.Errors.shoppingListAddFailed
        }
    }

    /// Navigates to the shopping list, or to the Upgrade paywall if access is not granted.
    func showShoppingList() {
        guard subscriptionService.canAccessFeature(.shoppingList) else {
            coordinator?.showUpgrade()
            return
        }
        coordinator?.showShoppingList()
    }

    /// Describes whether a recipe ingredient is covered by the user's current selection.
    enum IngredientStatus {
        /// The ingredient is explicitly selected, saved in pantry, or covered by a built-in staple assumption.
        case available
        /// The ingredient was not found in the user's selection.
        case missing
        /// No ingredient selection context is available; coverage cannot be determined.
        case unknown
    }

    /// Returns the availability status of a recipe ingredient relative to `selectedIngredients`.
    ///
    /// Uses the same bidirectional partial-match and pantry-staple logic as `RecipeMatchExplainer`.
    /// Returns `.unknown` when no selection context is available (e.g. browsing from My Kitchen).
    /// - Parameter ingredient: A recipe ingredient to evaluate.
    /// - Returns: `.available`, `.missing`, or `.unknown`.
    func ingredientStatus(_ ingredient: Ingredient) -> IngredientStatus {
        guard !selectedIngredients.isEmpty else { return .unknown }
        let recipeName = RecipeMatchExplainer.normalizedIngredientName(ingredient.name)
        guard !recipeName.isEmpty, let cache = currentIngredientMatchCache() else { return .available }
        if let status = cache.statusByIngredientName[recipeName] {
            return status
        }
        let isMissing = cache.normalizedMissingNames.contains { recipeName.contains($0) || $0.contains(recipeName) }
        return isMissing ? .missing : .available
    }

    /// Dismisses the error alert.
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Memoized match metadata used by repeated ingredient rows in SwiftUI renders.
    private struct IngredientMatchCache {
        /// Full pantry-plus breakdown for shopping-list and display decisions.
        let breakdown: RecipeMatchExplainer.IngredientMatchBreakdown
        /// Normalized true missing names, cached to avoid remapping during row status checks.
        let normalizedMissingNames: [String]
        /// Normalized recipe ingredient name to row status, precomputed once per recipe/selection pair.
        let statusByIngredientName: [String: IngredientStatus]
    }

    /// Returns the cached breakdown, lazily rebuilding if the cache was cleared.
    private func currentIngredientMatchCache() -> IngredientMatchCache? {
        if ingredientMatchCache == nil {
            rebuildIngredientMatchCache()
        }
        return ingredientMatchCache
    }

    /// Rebuilds ingredient match metadata when the displayed recipe changes.
    private func rebuildIngredientMatchCache() {
        guard !selectedIngredients.isEmpty else {
            ingredientMatchCache = nil
            return
        }

        let breakdown = RecipeMatchExplainer.ingredientBreakdown(
            recipe: recipe,
            selectedIngredients: selectedIngredients
        )
        let normalizedMissingNames = breakdown.missingIngredientNames
            .map(RecipeMatchExplainer.normalizedIngredientName)
            .filter { !$0.isEmpty }

        // Precompute status for the full displayed ingredient list so SwiftUI row rendering does not
        // rerun recipe-wide matching for every ingredient.
        var statusByIngredientName: [String: IngredientStatus] = [:]
        for ingredient in recipe.ingredients {
            let ingredientName = RecipeMatchExplainer.normalizedIngredientName(ingredient.name)
            guard !ingredientName.isEmpty else { continue }
            let isMissing = normalizedMissingNames.contains { ingredientName.contains($0) || $0.contains(ingredientName) }
            statusByIngredientName[ingredientName] = isMissing ? .missing : .available
        }

        ingredientMatchCache = IngredientMatchCache(
            breakdown: breakdown,
            normalizedMissingNames: normalizedMissingNames,
            statusByIngredientName: statusByIngredientName
        )
    }

    /// Checks whether the recipe is in the user's favourites list and sets `isFavorite`.
    private func loadFavoriteStatus() async {
        do {
            isFavorite = try await userDataService.isFavorite(recipe)
        } catch {
            logger.error("Failed to load favorite status: \(String(describing: error))")
            isFavorite = false
        }
    }

    /// Tracks a recipe view event for analytics and records the recipe in the recents list.
    private func recordView() async {
        analyticsService.track(.recipeViewed)
        do {
            try await userDataService.recordRecipeView(recipe)
        } catch {
            logger.error("Failed to record recipe detail view: \(String(describing: error))")
        }
    }
}
