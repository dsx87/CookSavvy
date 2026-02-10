//
//  RecipeDetailsViewModel.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI

@MainActor
final class RecipeDetailsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recipe: Recipe
    @Published var isFavorite: Bool = false
    @Published var isLoadingFavorite: Bool = false

    // MARK: - Properties

    private let userDataService: UserDataService

    // MARK: - Initialization

    init(recipe: Recipe, userDataService: UserDataService) {
        self.recipe = recipe
        self.userDataService = userDataService

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
