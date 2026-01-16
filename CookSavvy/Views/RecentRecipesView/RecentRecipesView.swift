//
//  RecentRecipesView.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI

struct RecentRecipesView: View {
    @StateObject private var viewModel: RecentRecipesViewModel

    init(userDataService: UserDataService, imageService: ImageService) {
        _viewModel = StateObject(
            wrappedValue: RecentRecipesViewModel(
                userDataService: userDataService,
                imageService: imageService
            )
        )
    }

    /// Convenience init for testing
    init(viewModel: RecentRecipesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading recent recipes...")
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if viewModel.recipes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No recent recipes")
                            .font(.headline)
                        Text("Recipes you view will appear here")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(viewModel.recipes) { recipe in
                        NavigationLink(value: recipe) {
                            RecipeResultCellView(
                                recipe: recipe,
                                image: viewModel.getImage(for: recipe)
                            )
                        }
                    }
                }
            }
            .navigationTitle("Recent Recipes")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailsView(
                    recipe: recipe,
                    userDataService: viewModel.userDataServiceForNavigation
                )
            }
            .task {
                await viewModel.loadRecentRecipes()
            }
        }
    }
}

#Preview("RecentRecipesView") {
    let dbInterface = DBInterface()
    return RecentRecipesView(
        userDataService: UserDataService(dbInterface: dbInterface),
        imageService: ImageService()
    )
}
