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
                    ProgressView(Strings.Favorites.loading)
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
                        Image(systemName: Icons.Favorites.empty)
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(Strings.Favorites.emptyTitle)
                            .font(.headline)
                        Text(Strings.Favorites.emptySubtitle)
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
                                    Label(Strings.Favorites.removeLabel, systemImage: Icons.Favorites.remove)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(Strings.Favorites.navigationTitle)
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
