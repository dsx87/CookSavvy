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
                    ProgressView(UIConstants.favoritesLoadingText)
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
                        Image(systemName: UIConstants.favoritesEmptyIconName)
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(UIConstants.favoritesEmptyTitle)
                            .font(.headline)
                        Text(UIConstants.favoritesEmptySubtitle)
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
                                    Label(UIConstants.favoritesRemoveLabelTitle, systemImage: UIConstants.favoritesRemoveIconName)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(UIConstants.favoritesNavigationTitle)
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
