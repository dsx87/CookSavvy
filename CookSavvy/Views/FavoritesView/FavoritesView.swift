//
//  FavoritesView.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel

    init(userDataService: UserDataService, imageService: ImageService) {
        _viewModel = StateObject(
            wrappedValue: FavoritesViewModel(
                userDataService: userDataService,
                imageService: imageService
            )
        )
    }

    /// Convenience init for testing
    init(viewModel: FavoritesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
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
                            NavigationLink(value: recipe) {
                                RecipeResultCellView(
                                    recipe: recipe,
                                    image: viewModel.getImage(for: recipe)
                                )
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
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailsView(
                    recipe: recipe,
                    userDataService: viewModel.userDataServiceForNavigation
                )
            }
            .task {
                await viewModel.loadFavorites()
            }
            .refreshable {
                await viewModel.loadFavorites()
            }
        }
    }
}

#Preview("FavoritesView") {
    let dbInterface = DBInterface()
    return FavoritesView(
        userDataService: UserDataService(dbInterface: dbInterface),
        imageService: ImageService()
    )
}
