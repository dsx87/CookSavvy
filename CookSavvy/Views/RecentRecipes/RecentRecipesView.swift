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
                    ProgressView(Strings.Recent.loading)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: UI.Common.stackSpacing) {
                        Image(systemName: Icons.Common.error)
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if viewModel.recipes.isEmpty {
                    VStack(spacing: UI.Common.stackSpacing) {
                        Image(systemName: Icons.Recent.empty)
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(Strings.Recent.emptyTitle)
                            .font(.headline)
                        Text(Strings.Recent.emptySubtitle)
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
            .navigationTitle(Strings.Recent.navigationTitle)
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
