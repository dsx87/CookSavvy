//
//  IngredientsInputViewModel.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

@MainActor
final class IngredientsInputViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var ingredients: [Ingredient] = []
    @Published var recentIngredients: [Ingredient] = []
    @Published var popularIngredients: [Ingredient] = []
    @Published var searchText: String = "" {
        didSet {
            handleSearchTextChange(searchText)
        }
    }
    @Published var selectedIngredients: Set<Ingredient> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Properties

    let navigationTitle = "Ingredients Input"

    var isIngredientsReady: Bool {
        databaseInitService.state.isIngredientsReady
    }

    /// Returns ingredients for the fast selector - recent if available, otherwise popular
    var fastSelectorIngredients: [Ingredient] {
        // TODO: Fix popular vs recent ingredients
        
        let recentCount = recentIngredients.count
        if recentCount <= 9 {
            return recentIngredients + popularIngredients.dropFirst(recentCount)
        } else {
            return recentIngredients
        }
    }

    private let ingredientsService: IngredientsService
    private let userDataService: UserDataService
    private let databaseInitService: DatabaseInitializationService
    private let ingredientDetectionService: IngredientDetectionServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private(set) weak var coordinator: DiscoverCoordinator?
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        ingredientsService: IngredientsService,
        userDataService: UserDataService,
        databaseInitService: DatabaseInitializationService,
        ingredientDetectionService: IngredientDetectionServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        coordinator: DiscoverCoordinator?
    ) {
        self.ingredientsService = ingredientsService
        self.userDataService = userDataService
        self.databaseInitService = databaseInitService
        self.ingredientDetectionService = ingredientDetectionService
        self.subscriptionService = subscriptionService
        self.coordinator = coordinator

        Task {
            await loadRecentIngredients()
            await loadPopularIngredients()
        }
    }

    // MARK: - Public Methods

    func autocompletionDidHide() {
        clearText()
    }

    func selectIngredient(_ ingredient: Ingredient) {
        // Prevent duplicates
        guard !selectedIngredients.contains(ingredient) else {
            return
        }
        selectedIngredients.insert(ingredient)
    }

    func deselectIngredient(_ ingredient: Ingredient) {
        selectedIngredients.remove(ingredient)
    }

    func toggleIngredient(_ ingredient: Ingredient) {
        if selectedIngredients.contains(ingredient) {
            deselectIngredient(ingredient)
        } else {
            selectIngredient(ingredient)
        }
    }

    func loadRecentIngredients() async {
        do {
            recentIngredients = try await userDataService.getRecentIngredients(limit: 10)
        } catch {
            print("❌ Failed to load recent ingredients: \(error)")
        }
    }

    func loadPopularIngredients() async {
        do {
            popularIngredients = try await userDataService.getPopularIngredients(limit: 10)
        } catch {
            print("❌ Failed to load popular ingredients: \(error)")
        }
    }

    func onFindRecipes() async {
        // Record ingredient usage when user searches for recipes
        guard !selectedIngredients.isEmpty else { return }

        do {
            try await userDataService.recordIngredientUsage(Array(selectedIngredients))
            // Reload recent and popular ingredients after recording
            await loadRecentIngredients()
            await loadPopularIngredients()
        } catch {
            print("❌ Failed to record ingredient usage: \(error)")
        }
    }

    func navigateToRecipesResult() {
        coordinator?.showRecipesResult()
    }
    
    func addDetectedIngredients(_ ingredients: [Ingredient]) {
        for ingredient in ingredients {
            selectedIngredients.insert(ingredient)
        }
    }
    
    func dismissCamera() {
        coordinator?.dismissSheet()
    }
    
    func handleCameraTap() {
        guard subscriptionService.canAccessFeature(.cameraIngredientDetection) else {
            coordinator?.showUpgrade()
            return
        }
        coordinator?.showCamera()
    }
    
    func canAccessCamera() -> Bool {
        subscriptionService.canAccessFeature(.cameraIngredientDetection)
    }

    // MARK: - Private Methods

    private func handleSearchTextChange(_ query: String) {
        // Cancel previous search
        searchTask?.cancel()

        guard !query.isEmpty else {
            ingredients = []
            isLoading = false
            return
        }

        searchTask = Task {
            await searchIngredients(query)
        }
    }

    private func searchIngredients(_ query: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Add small delay for debouncing
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms

            // Check if task was cancelled
            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            let searchResults = try await ingredientsService.searchFullIngredients(
                matching: query,
                limit: 20
            )

            // Smart suggestions: prioritize recent ingredients in results
            let recentNames = Set(recentIngredients.map { $0.name.lowercased() })
            ingredients = searchResults.sorted { a, b in
                let aRecent = recentNames.contains(a.name.lowercased())
                let bRecent = recentNames.contains(b.name.lowercased())
                // Recent ingredients come first
                if aRecent != bRecent {
                    return aRecent
                }
                // Otherwise sort alphabetically
                return a.name < b.name
            }

            isLoading = false
        } catch is CancellationError {
            // Task was cancelled - this is expected, don't show error
            ingredients = []
            isLoading = false
        } catch {
            // Actual error occurred
            ingredients = []
            isLoading = false
            errorMessage = "Failed to search ingredients: \(error.localizedDescription)"
        }
    }

    private func clearText() {
        searchText = ""
    }

    // MARK: - Cleanup

    deinit {
        searchTask?.cancel()
    }
}
