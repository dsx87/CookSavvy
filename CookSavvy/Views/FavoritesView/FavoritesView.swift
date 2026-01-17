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
                    ProgressView("Loading favorites...")
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
                        Image(systemName: "heart")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No favorite recipes")
                            .font(.headline)
                        Text("Tap the heart icon on recipes to save them here")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.recipes) { recipe in
                            RecipeResultCellView(
                                recipe: recipe,
                                image: viewModel.getImage(for: recipe)
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
                                    Label("Remove", systemImage: "heart.slash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
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
