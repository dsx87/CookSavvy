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
                    ProgressView(UI.Recent.loadingText)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: UI.Common.stackSpacing) {
                        Image(systemName: UI.Common.errorIcon)
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if viewModel.recipes.isEmpty {
                    VStack(spacing: UI.Common.stackSpacing) {
                        Image(systemName: UI.Recent.emptyIcon)
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(UI.Recent.emptyTitle)
                            .font(.headline)
                        Text(UI.Recent.emptySubtitle)
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
            .navigationTitle(UI.Recent.navigationTitle)
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
