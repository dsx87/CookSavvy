//
//  FavoritesViewModel.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI

@MainActor
final class FavoritesViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recipes: [Recipe] = []
    @Published var images: [String: UIImage] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Properties

    private let userDataService: UserDataService
    private let imageService: ImageService
    private weak var coordinator: DiscoverCoordinator?

    // MARK: - Initialization

    init(
        userDataService: UserDataService,
        imageService: ImageService,
        coordinator: DiscoverCoordinator?
    ) {
        self.userDataService = userDataService
        self.imageService = imageService
        self.coordinator = coordinator
    }

    // MARK: - Public Methods

    func loadFavorites() async {
        isLoading = true
        errorMessage = nil

        do {
            defer { isLoading = false }

            recipes = try await userDataService.getFavorites()
            images = try await imageService.loadImages(for: recipes)
        } catch {
            print("❌ Error loading favorites: \(error)")
            errorMessage = "Failed to load favorites: \(error.localizedDescription)"
            recipes = []
            images = [:]
            isLoading = false
        }
    }

    func removeFavorite(_ recipe: Recipe) async {
        do {
            _ = try await userDataService.toggleFavorite(recipe)
            // Reload favorites after removing
            await loadFavorites()
        } catch {
            print("❌ Failed to remove favorite: \(error)")
        }
    }

    func getImage(for recipe: Recipe) -> UIImage? {
        images[recipe.id]
    }

    func handleRecipeSelection(_ recipe: Recipe) {
        coordinator?.showRecipeDetails(recipe: recipe)
    }
}
