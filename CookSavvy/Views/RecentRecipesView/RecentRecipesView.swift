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
                    ProgressView(UIConstants.recentLoadingText)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: UIConstants.statusStackSpacing) {
                        Image(systemName: UIConstants.errorIconName)
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if viewModel.recipes.isEmpty {
                    VStack(spacing: UIConstants.statusStackSpacing) {
                        Image(systemName: UIConstants.recentEmptyIconName)
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(UIConstants.recentEmptyTitle)
                            .font(.headline)
                        Text(UIConstants.recentEmptySubtitle)
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
            .navigationTitle(UIConstants.recentNavigationTitle)
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
