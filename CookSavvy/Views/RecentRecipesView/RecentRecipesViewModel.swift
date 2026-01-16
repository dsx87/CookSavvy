//
//  RecentRecipesViewModel.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI

@MainActor
final class RecentRecipesViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recipes: [Recipe] = []
    @Published var images: [String: UIImage] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Properties

    private let userDataService: UserDataService
    private let imageService: ImageService

    var userDataServiceForNavigation: UserDataService {
        userDataService
    }

    // MARK: - Initialization

    init(userDataService: UserDataService, imageService: ImageService) {
        self.userDataService = userDataService
        self.imageService = imageService
    }

    // MARK: - Public Methods

    func loadRecentRecipes() async {
        isLoading = true
        errorMessage = nil

        do {
            defer { isLoading = false }

            recipes = try await userDataService.getRecentRecipes(limit: 50)
            images = try await imageService.loadImages(for: recipes)
        } catch {
            print("❌ Error loading recent recipes: \(error)")
            errorMessage = "Failed to load recent recipes: \(error.localizedDescription)"
            recipes = []
            images = [:]
            isLoading = false
        }
    }

    func getImage(for recipe: Recipe) -> UIImage? {
        images[recipe.id]
    }
}
