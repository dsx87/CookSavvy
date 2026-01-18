//
//  RecentRecipesView.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI

struct RecentRecipesView: View {
    @ObservedObject var viewModel: RecentRecipesViewModel

    var body: some View {
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
                        RecipeResultCellView(
                            recipe: recipe
                        )
                        .onTapGesture {
                            viewModel.handleRecipeSelection(recipe)
                        }
                    }
                }
            }
            .navigationTitle("Recent Recipes")
            .task {
                await viewModel.loadRecentRecipes()
            }
            .refreshable {
                await viewModel.loadRecentRecipes()
            }
    }
}

#Preview("RecentRecipesView") {
    let dbInterface = DBInterface()
    return RecentRecipesView(
        viewModel: RecentRecipesViewModel(
            userDataService: UserDataService(dbInterface: dbInterface),
            imageService: ImageService(),
            coordinator: nil
        )
    )
}
