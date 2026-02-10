//
//  FavoritesView.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: FavoritesViewModel

    var body: some View {
            Group {
                if viewModel.isLoading {
                    ProgressView(UI.Favorites.loadingText)
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
                        Image(systemName: UI.Favorites.emptyIcon)
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(UI.Favorites.emptyTitle)
                            .font(.headline)
                        Text(UI.Favorites.emptySubtitle)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.recipes) { recipe in
                            RecipeResultCellView(
                                recipe: recipe
                            )
                            .onTapGesture {
                                viewModel.handleRecipeSelection(recipe)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.removeFavorite(recipe)
                                    }
                                } label: {
                                    Label(UI.Favorites.removeLabelTitle, systemImage: UI.Favorites.removeIcon)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(UI.Favorites.navigationTitle)
            .task {
                await viewModel.loadFavorites()
            }
            .refreshable {
                await viewModel.loadFavorites()
            }
    }
}

#Preview("FavoritesView") {
    let dbInterface = DBInterface()
    return FavoritesView(
        viewModel: FavoritesViewModel(
            userDataService: UserDataService(dbInterface: dbInterface),
            imageService: ImageService(),
            coordinator: nil
        )
    )
}
